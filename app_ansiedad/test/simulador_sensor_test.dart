import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/app_config.dart';
import 'package:app_ansiedad/medicion/calculo_sesion.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';
import 'package:app_ansiedad/repositories/simulador_sensor.dart';

void main() {
  test('cada segundo trae 0, 1 o 2 RR', () {
    final sim = SimuladorSensor(rng: Random(1));
    for (var i = 0; i < 600; i++) {
      expect(sim.siguiente().rr.length, inInclusiveRange(0, 2));
    }
  });

  test('forzar mala señal da segundos sin dedo', () {
    final sim = SimuladorSensor(rng: Random(2))..forzarMalaSenal = true;
    for (var i = 0; i < 20; i++) {
      expect(sim.siguiente().dedo, isFalse);
    }
  });

  test('una sesión simulada se completa con datos que acepta el backend', () {
    for (var semilla = 0; semilla < 20; semilla++) {
      final sim = SimuladorSensor(rng: Random(semilla))..colocarDedo();
      final a = AcumuladorSesion(fechaInicio: DateTime.now());
      while (!a.completa && !a.agotada) {
        a.agregar(sim.siguiente());
      }
      expect(a.completa, isTrue, reason: 'semilla $semilla');
      final s = a.construir(origen: OrigenSesion.simulacion);
      expect(s.hrvRmssd, inExclusiveRange(0, 300));
      expect(s.hrvRmssd, inInclusiveRange(10, 80), reason: 'RMSSD fisiológico, semilla $semilla');
      expect(s.duracionValidaSeg, greaterThanOrEqualTo(120));
      expect(s.duracionValidaSeg, lessThan(s.duracionTotalSeg)); // hubo estabilización
      expect(s.serie.length, lessThanOrEqualTo(360));
      expect(s.bpmPromedio, inInclusiveRange(s.bpmMin, s.bpmMax));
      expect(s.duracionTotalSeg, lessThanOrEqualTo(ConfigMedicion.topeTotalSeg));
    }
  });
}
