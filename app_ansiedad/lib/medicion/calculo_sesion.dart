import 'dart:math';
import '../app_config.dart';
import '../models/lectura_cruda.dart';
import '../models/sesion_medicion.dart';

/// Por qué un segundo de captura no cuenta como señal válida. La UI lo
/// traduce a una guía positiva ("Acomoda tu dedo"...), nunca a un veredicto.
enum MotivoSenal { valida, sinDedo, movimiento, artefacto }

class _Segundo {
  final bool valido;
  final int bpm;
  final int spo2;
  const _Segundo(this.valido, this.bpm, this.spo2);
}

/// Cuadrado de la diferencia entre dos RR consecutivos, con el segundo `t`
/// en que ocurrió el segundo de ellos.
class _Diferencia {
  final int t;
  final double cuadrado;
  const _Diferencia(this.t, this.cuadrado);
}

double redondear(double valor, int decimales) {
  final factor = pow(10, decimales);
  return (valor * factor).round() / factor;
}

/// RMSSD = raíz de la media de los cuadrados de las diferencias sucesivas de
/// RR. Null si no hay diferencias.
double? _rmssd(Iterable<_Diferencia> diferencias) {
  if (diferencias.isEmpty) return null;
  final suma = diferencias.fold<double>(0, (s, d) => s + d.cuadrado);
  return sqrt(suma / diferencias.length);
}

/// Acumula, segundo a segundo, la captura de una sesión de medición y arma el
/// resumen para `POST /api/sesiones` (DISENO_FLUJO_MEDICION.md §3).
///
/// Lógica pura (sin Flutter, red ni temporizadores) para poder probarla con
/// `flutter test`. Quien la usa entrega UNA lectura por segundo, con los RR de
/// los latidos ocurridos en ese segundo.
///
/// - Un segundo con mala señal cuenta en la duración total pero no en la
///   válida, y corta la cadena de RR: el RMSSD nunca resta dos RR separados
///   por un hueco.
/// - La serie usa una malla de 5 s; un tramo solo genera punto si tuvo
///   suficientes segundos válidos, así que los huecos quedan como saltos en `t`.
class AcumuladorSesion {
  final DateTime fechaInicio;

  AcumuladorSesion({required this.fechaInicio});

  final List<_Segundo> _segundos = [];
  final List<_Diferencia> _diferencias = [];

  /// Último RR aceptado del tramo continuo actual; null tras un hueco.
  int? _rrAnterior;
  int _validos = 0;

  int get segundosTotales => _segundos.length;
  int get segundosValidos => _validos;
  bool get completa => _validos >= ConfigMedicion.objetivoValidoSeg;
  bool get agotada => !completa && _segundos.length >= ConfigMedicion.topeTotalSeg;

  /// Avance de 0 a 1: solo crece con señal válida.
  double get progreso => min(1.0, _validos / ConfigMedicion.objetivoValidoSeg);

  /// Registra la lectura del siguiente segundo y dice si fue válida.
  MotivoSenal agregar(LecturaCruda lectura) {
    final t = _segundos.length;
    final motivo = _clasificar(lectura);
    if (motivo != MotivoSenal.valida) {
      _segundos.add(const _Segundo(false, 0, 0));
      _rrAnterior = null;
      return motivo;
    }
    for (final rr in lectura.rr) {
      final anterior = _rrAnterior;
      if (anterior != null) {
        final d = (rr - anterior).toDouble();
        _diferencias.add(_Diferencia(t, d * d));
      }
      _rrAnterior = rr;
    }
    _segundos.add(_Segundo(true, lectura.bpm, lectura.spo2));
    _validos++;
    return MotivoSenal.valida;
  }

  MotivoSenal _clasificar(LecturaCruda l) {
    if (!l.dedo) return MotivoSenal.sinDedo;
    if (!l.estable) return MotivoSenal.movimiento;
    if (l.bpm < ConfigMedicion.bpmMin || l.bpm > ConfigMedicion.bpmMax) return MotivoSenal.artefacto;
    if (l.spo2 < ConfigMedicion.spo2Min || l.spo2 > 100) return MotivoSenal.artefacto;
    var anterior = _rrAnterior;
    for (final rr in l.rr) {
      if (rr < ConfigMedicion.rrMinMs || rr > ConfigMedicion.rrMaxMs) return MotivoSenal.artefacto;
      if (anterior != null && (rr - anterior).abs() > anterior * ConfigMedicion.rrMaxVariacion) {
        return MotivoSenal.artefacto;
      }
      anterior = rr;
    }
    return MotivoSenal.valida;
  }

  /// Arma la sesión. Solo se llama con la medición completa; si no, o si no
  /// hubo latidos suficientes para el RMSSD, lanza [StateError].
  SesionMedicion construir({required OrigenSesion origen}) {
    if (!completa) {
      throw StateError('La sesión no está completa ($_validos s válidos).');
    }
    final rmssd = _rmssd(_diferencias);
    final serie = _serie();
    if (rmssd == null || serie.isEmpty) {
      throw StateError('La sesión no tiene latidos suficientes para calcular la HRV.');
    }

    final validos = _segundos.where((s) => s.valido).toList();
    final bpms = validos.map((s) => s.bpm).toList();
    final spo2s = validos.map((s) => s.spo2).toList();
    final hrvs = serie.map((p) => p.hrv).toList();

    return SesionMedicion(
      fechaInicio: fechaInicio,
      duracionTotalSeg: _segundos.length,
      duracionValidaSeg: _validos,
      hrvRmssd: redondear(rmssd, 2),
      hrvMin: hrvs.reduce(min),
      hrvMax: hrvs.reduce(max),
      bpmPromedio: redondear(_media(bpms), 1),
      bpmMin: bpms.reduce(min),
      bpmMax: bpms.reduce(max),
      spo2Promedio: redondear(_media(spo2s), 1),
      spo2Min: spo2s.reduce(min),
      spo2Max: spo2s.reduce(max),
      indiceCalidad: redondear(_validos / _segundos.length, 3),
      serie: serie,
      origen: origen,
    );
  }

  List<PuntoSerie> _serie() {
    const paso = ConfigMedicion.intervaloSerieSeg;
    final puntos = <PuntoSerie>[];
    for (var inicio = 0; inicio < _segundos.length; inicio += paso) {
      final fin = min(inicio + paso, _segundos.length) - 1;
      final tramo = _segundos.sublist(inicio, fin + 1).where((s) => s.valido).toList();
      if (tramo.length < ConfigMedicion.minValidosPorTramo) continue;

      final hrv = _rmssd(_diferencias.where((d) => d.t > fin - ConfigMedicion.ventanaHrvSeg && d.t <= fin));
      if (hrv == null) continue;

      puntos.add(PuntoSerie(
        t: inicio,
        bpm: redondear(_media(tramo.map((s) => s.bpm)), 1),
        spo2: redondear(_media(tramo.map((s) => s.spo2)), 1),
        hrv: redondear(hrv, 2),
      ));
    }
    return puntos;
  }

  static double _media(Iterable<int> valores) => valores.reduce((a, b) => a + b) / valores.length;
}
