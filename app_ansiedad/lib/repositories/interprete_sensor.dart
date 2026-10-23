import 'dart:convert';
import '../models/lectura_cruda.dart';

/// Si el firmware del sensor habla el contrato de `CONTRATO_SENSOR.md`.
enum EstadoFirmware { verificando, compatible, noCompatible }

/// Convierte cada línea del sensor en la [LecturaCruda] de un segundo,
/// aplicando el contrato v1 de `CONTRATO_SENSOR.md` (Fase M7a). Lógica pura,
/// sin Bluetooth ni Flutter: se prueba con `flutter test`
/// (test/interprete_sensor_test.dart). Solo es del sensor: la simulación arma
/// sus lecturas directamente.
///
/// - **Estricto:** un paquete al que le falte (o traiga con otro tipo) `v`,
///   `seq`, `bpm`, `spo2`, `rr`, `dedo` o `estable` es un segundo SIN DEDO.
///   Nunca se da por bueno ni hereda valores del paquete anterior.
/// - **Paquetes perdidos:** si `seq` no es el anterior + 1, la lectura sale
///   con `cortaCadenaRr` y el cálculo no resta su primer RR contra el último
///   de antes del hueco.
/// - **Firmware viejo:** los primeros paquetes deciden. El primero con
///   `"v":1` lo da por [EstadoFirmware.compatible]; [paquetesParaDecidir]
///   paquetes legibles sin `v` (el firmware que manda `hrv` ya calculado), o
///   uno con otra versión, lo dejan en [EstadoFirmware.noCompatible]. Mientras
///   se verifica, y si no es compatible, no sale ninguna lectura: la medición
///   no se ofrece (paso 4) y el paciente no espera 3 minutos para nada.
///   Se vuelve a decidir al reconectar ([reiniciar]).
/// - **A lo más una lectura por segundo de reloj:** si el sensor manda más
///   rápido que 1 Hz, lo que sobra se junta con la siguiente lectura (RR
///   seguidos, `dedo`/`estable` solo si ambas los tienen, `bpm`/`spo2` de la
///   más reciente), para que la duración de la medición no se infle. Usa una
///   "cubeta" de crédito: gana 1 por segundo transcurrido (tope 2) y gasta 1
///   por lectura publicada, así tolera el desfase normal de los paquetes
///   (0.98 s, 1.02 s…) sin juntar de más.
class InterpreteSensor {
  /// Paquetes legibles sin `v` tras los que el firmware es "no compatible".
  static const int paquetesParaDecidir = 3;
  static const int versionContrato = 1;
  static const double _creditoMaximo = 2;

  final DateTime Function() _reloj;

  InterpreteSensor({DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  EstadoFirmware _firmware = EstadoFirmware.verificando;
  EstadoFirmware get firmware => _firmware;

  int _sinVersion = 0;
  int? _ultimoSeq;
  double _credito = _creditoMaximo;
  DateTime? _ultimaVez;
  LecturaCruda? _retenida;

  /// Procesa una línea y devuelve la lectura a publicar, o null si no hay
  /// nada que publicar todavía (línea ilegible, firmware en verificación o
  /// no compatible, o lectura retenida para juntarla con la siguiente).
  LecturaCruda? procesar(String linea) {
    final Map<String, dynamic> datos;
    try {
      final decodificado = jsonDecode(linea);
      if (decodificado is! Map<String, dynamic>) return null;
      datos = decodificado;
    } on FormatException {
      return null; // basura del serial: ni cuenta para decidir el firmware
    }

    if (_firmware == EstadoFirmware.verificando) _decidirFirmware(datos);
    if (_firmware != EstadoFirmware.compatible) return null;

    return _publicar(_lectura(datos));
  }

  /// Al conectar (o reconectar) el sensor: todo vuelve a empezar.
  void reiniciar() {
    _firmware = EstadoFirmware.verificando;
    _sinVersion = 0;
    _ultimoSeq = null;
    _credito = _creditoMaximo;
    _ultimaVez = null;
    _retenida = null;
  }

  void _decidirFirmware(Map<String, dynamic> datos) {
    final v = datos['v'];
    if (v == versionContrato) {
      _firmware = EstadoFirmware.compatible;
    } else if (v != null) {
      _firmware = EstadoFirmware.noCompatible; // otra versión del contrato
    } else if (++_sinVersion >= paquetesParaDecidir) {
      _firmware = EstadoFirmware.noCompatible;
    }
  }

  static final _sinDedo = LecturaCruda(bpm: 0, spo2: 0, hrv: 0, dedo: false, estable: false);

  LecturaCruda _lectura(Map<String, dynamic> d) {
    final v = d['v'], seq = d['seq'], bpm = d['bpm'], spo2 = d['spo2'];
    final rr = d['rr'], dedo = d['dedo'], estable = d['estable'];
    final completo = v == versionContrato &&
        seq is int &&
        bpm is int &&
        spo2 is int &&
        rr is List &&
        rr.every((x) => x is int) &&
        dedo is bool &&
        estable is bool;
    if (!completo) {
      // El segundo inválido ya corta la cadena de RR; el siguiente seq no se
      // compara contra uno de antes del hueco.
      _ultimoSeq = null;
      return _sinDedo;
    }
    final anterior = _ultimoSeq;
    _ultimoSeq = seq;
    return LecturaCruda(
      bpm: bpm,
      spo2: spo2,
      hrv: 0, // el sensor ya no manda hrv: el RMSSD lo calcula la app
      rr: List<int>.from(rr),
      dedo: dedo,
      estable: estable,
      cortaCadenaRr: anterior != null && seq != anterior + 1,
    );
  }

  LecturaCruda? _publicar(LecturaCruda lectura) {
    final ahora = _reloj();
    final antes = _ultimaVez;
    if (antes != null) {
      final segundos = ahora.difference(antes).inMilliseconds / 1000;
      _credito = (_credito + segundos).clamp(0, _creditoMaximo).toDouble();
    }
    _ultimaVez = ahora;

    final retenida = _retenida;
    final junta = retenida == null ? lectura : _juntar(retenida, lectura);
    if (_credito >= 1) {
      _credito -= 1;
      _retenida = null;
      return junta;
    }
    _retenida = junta;
    return null;
  }

  /// Dos paquetes que cayeron en el mismo segundo, como uno solo.
  static LecturaCruda _juntar(LecturaCruda a, LecturaCruda b) {
    // Si hubo paquetes perdidos entre a y b, los RR de a no se encadenan con
    // los de b: se quedan solo los de b y la lectura corta la cadena.
    final corta = b.cortaCadenaRr;
    return LecturaCruda(
      bpm: b.bpm,
      spo2: b.spo2,
      hrv: 0,
      rr: corta ? b.rr : [...a.rr, ...b.rr],
      dedo: a.dedo && b.dedo,
      estable: a.estable && b.estable,
      cortaCadenaRr: corta || a.cortaCadenaRr,
    );
  }
}
