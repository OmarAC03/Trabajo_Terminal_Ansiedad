import 'dart:math';
import '../models/lectura_cruda.dart';

/// Simulador del sensor para probar sin hardware (Fase M1b).
///
/// Entrega UNA lectura por segundo, como la espera `AcumuladorSesion`, con los
/// intervalos RR de los latidos ocurridos en ese segundo. Los latidos corren en
/// un reloj continuo en milisegundos, así que según el ritmo un segundo trae 0,
/// 1 o 2 RR (a 75 lpm, RR ≈ 800 ms: la mayoría de los segundos 1 y algunos 2).
///
/// Variabilidad realista: cada RR = RR base del ritmo + una oscilación
/// respiratoria (arritmia sinusal) + ruido; da un RMSSD de unos 25-45 ms en
/// reposo. Con ritmo alto (picos ocasionales) la variabilidad baja, como en la
/// activación simpática.
///
/// Mala señal: unos segundos de estabilización al colocar el dedo, episodios
/// espontáneos de "dedo fuera" o "movimiento" de 5-15 s, y [forzarMalaSenal]
/// para la prueba manual.
class SimuladorSensor {
  final Random _rng;

  SimuladorSensor({Random? rng}) : _rng = rng ?? Random();

  /// Mientras sea true, cada segundo sale sin dedo (botón de prueba).
  bool forzarMalaSenal = false;

  // Reloj de latidos (ms simulados).
  double _relojMs = 0;
  double _ultimoLatidoMs = 0;
  int _proximoRr = 830;
  int _nLatido = 0;

  // Ritmo: deriva suave hacia un objetivo que cambia de vez en cuando.
  double _bpmBase = 72;
  double _bpmObjetivo = 72;
  double _spo2 = 97.5;

  int _estabilizacionRestante = 0;
  int _episodioRestante = 0;
  bool _episodioSinDedo = false;

  /// RR recientes para el `hrv` de la vista en vivo del Monitor.
  final List<int> _ultimosRr = [];

  /// Simula que el paciente acaba de colocar el dedo: unos segundos de señal
  /// inestable antes de que se pueda medir.
  void colocarDedo() {
    _estabilizacionRestante = 5 + _rng.nextInt(4); // 5-8 s
    _episodioRestante = 0;
  }

  LecturaCruda siguiente() {
    _actualizarRitmo();
    final rr = _latidosDelSegundo();
    _spo2 = (_spo2 + (_rng.nextDouble() - 0.5) * 0.6).clamp(95.0, 99.0);

    var dedo = true;
    var estable = true;
    if (_estabilizacionRestante > 0) {
      _estabilizacionRestante--;
      estable = false;
    } else if (forzarMalaSenal) {
      dedo = false;
    } else {
      if (_episodioRestante == 0 && _rng.nextDouble() < 1 / 45) {
        _episodioRestante = 5 + _rng.nextInt(11); // 5-15 s
        _episodioSinDedo = _rng.nextBool();
      }
      if (_episodioRestante > 0) {
        _episodioRestante--;
        if (_episodioSinDedo) {
          dedo = false;
        } else {
          estable = false;
        }
      }
    }

    if (!dedo) {
      return LecturaCruda(bpm: 0, spo2: 0, hrv: 0, dedo: false, estable: false);
    }
    final bpm = rr.isEmpty ? _bpmBase.round() : (60000 / (rr.reduce((a, b) => a + b) / rr.length)).round();
    return LecturaCruda(
      bpm: bpm,
      spo2: _spo2.round(),
      hrv: _rmssdReciente(),
      rr: rr,
      estable: estable,
    );
  }

  void _actualizarRitmo() {
    // Pico de ritmo ocasional (para ver el semáforo del Monitor cambiar) o
    // vuelta a reposo.
    if (_rng.nextDouble() < 0.02) {
      _bpmObjetivo = _rng.nextDouble() < 0.15 ? 95 + _rng.nextDouble() * 15 : 65 + _rng.nextDouble() * 15;
    }
    _bpmBase += (_bpmObjetivo - _bpmBase) * 0.05;
  }

  /// RR de los latidos que caen dentro del segundo que empieza en `_relojMs`.
  List<int> _latidosDelSegundo() {
    final rr = <int>[];
    final finSegundo = _relojMs + 1000;
    while (_ultimoLatidoMs + _proximoRr <= finSegundo) {
      _ultimoLatidoMs += _proximoRr;
      rr.add(_proximoRr);
      _ultimosRr.add(_proximoRr);
      if (_ultimosRr.length > 10) _ultimosRr.removeAt(0);
      _proximoRr = _nuevoRr();
    }
    _relojMs = finSegundo;
    return rr;
  }

  int _nuevoRr() {
    final base = 60000 / _bpmBase;
    final amplitud = _bpmBase > 90 ? 0.4 : 1.0;
    final respiracion = 25 * sin(2 * pi * _nLatido / 4.5);
    _nLatido++;
    return (base + amplitud * (respiracion + 12 * _gaussiana())).round();
  }

  /// Normal estándar (Box-Muller).
  double _gaussiana() {
    final u1 = 1 - _rng.nextDouble();
    final u2 = _rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  int _rmssdReciente() {
    if (_ultimosRr.length < 2) return 0;
    var suma = 0.0;
    for (var i = 1; i < _ultimosRr.length; i++) {
      final d = _ultimosRr[i] - _ultimosRr[i - 1];
      suma += d * d;
    }
    return sqrt(suma / (_ultimosRr.length - 1)).round();
  }
}
