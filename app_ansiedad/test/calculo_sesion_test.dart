import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/app_config.dart';
import 'package:app_ansiedad/medicion/calculo_sesion.dart';
import 'package:app_ansiedad/models/lectura_cruda.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';

/// Lectura de un segundo con señal buena por defecto.
LecturaCruda seg({
  List<int> rr = const [],
  int bpm = 75,
  int spo2 = 97,
  bool dedo = true,
  bool estable = true,
}) =>
    LecturaCruda(bpm: bpm, spo2: spo2, hrv: 0, rr: rr, dedo: dedo, estable: estable);

/// Un latido por segundo alternando entre [a] y [b] ms.
LecturaCruda alterno(int i, int a, int b, {int bpm = 75}) => seg(rr: [i.isEven ? a : b], bpm: bpm);

AcumuladorSesion nuevo() => AcumuladorSesion(fechaInicio: DateTime.now().subtract(const Duration(minutes: 4)));

const objetivo = ConfigMedicion.objetivoValidoSeg;

void main() {
  group('Clasificación de cada segundo', () {
    test('sin dedo, movimiento y fuera de rango no son válidos', () {
      final a = nuevo();
      expect(a.agregar(seg(dedo: false)), MotivoSenal.sinDedo);
      expect(a.agregar(seg(estable: false)), MotivoSenal.movimiento);
      expect(a.agregar(seg(bpm: 30)), MotivoSenal.artefacto);
      expect(a.agregar(seg(spo2: 70)), MotivoSenal.artefacto);
      expect(a.agregar(seg(rr: [250])), MotivoSenal.artefacto);
      expect(a.agregar(seg(rr: [800])), MotivoSenal.valida);
      expect(a.segundosTotales, 6);
      expect(a.segundosValidos, 1);
    });

    test('un RR que salta más de 20 % respecto al anterior es artefacto', () {
      final a = nuevo();
      expect(a.agregar(seg(rr: [800])), MotivoSenal.valida);
      expect(a.agregar(seg(rr: [1000])), MotivoSenal.artefacto); // +25 %
      // Tras el hueco la cadena se reinicia: el mismo 1000 ya se acepta.
      expect(a.agregar(seg(rr: [1000])), MotivoSenal.valida);
    });
  });

  group('Progreso y término', () {
    test('el progreso solo avanza con señal válida', () {
      final a = nuevo();
      for (var i = 0; i < 10; i++) {
        a.agregar(seg(dedo: false));
      }
      expect(a.progreso, 0);
      for (var i = 0; i < objetivo ~/ 2; i++) {
        a.agregar(alterno(i, 800, 820));
      }
      expect(a.progreso, closeTo(0.5, 0.01));
      expect(a.completa, isFalse);
    });

    test('construir antes de completar lanza StateError', () {
      final a = nuevo();
      a.agregar(alterno(0, 800, 820));
      expect(() => a.construir(origen: OrigenSesion.simulacion), throwsStateError);
    });

    test('se agota al llegar al tope sin juntar el objetivo', () {
      final a = nuevo();
      for (var i = 0; i < ConfigMedicion.topeTotalSeg; i++) {
        a.agregar(seg(dedo: i % 4 == 0, rr: [800])); // 150 s válidos < 180
      }
      expect(a.segundosValidos, lessThan(objetivo));
      expect(a.completa, isFalse);
      expect(a.agotada, isTrue);
    });
  });

  group('RMSSD', () {
    test('diferencias constantes de 20 ms dan RMSSD 20', () {
      final a = nuevo();
      for (var i = 0; i < objetivo; i++) {
        a.agregar(alterno(i, 800, 820));
      }
      final s = a.construir(origen: OrigenSesion.simulacion);
      expect(s.hrvRmssd, 20.0);
      expect(s.serie.every((p) => p.hrv == 20.0), isTrue);
      expect(s.hrvMin, 20.0);
      expect(s.hrvMax, 20.0);
    });

    test('fórmula estándar: 800, 810, 790, 800 da √200 = 14.14', () {
      final a = nuevo();
      const rrs = [800, 810, 790, 800];
      for (var i = 0; i < objetivo; i++) {
        a.agregar(seg(rr: i < rrs.length ? [rrs[i]] : const []));
      }
      expect(a.construir(origen: OrigenSesion.simulacion).hrvRmssd, 14.14);
    });

    test('no resta RR separados por un hueco de mala señal', () {
      final a = nuevo();
      for (var i = 0; i < 90; i++) {
        a.agregar(alterno(i, 800, 820)); // diferencias de ±20
      }
      for (var i = 0; i < 10; i++) {
        a.agregar(seg(dedo: false));
      }
      for (var i = 0; i < 90; i++) {
        a.agregar(alterno(i, 1000, 1010, bpm: 60)); // diferencias de ±10
      }
      final s = a.construir(origen: OrigenSesion.simulacion);
      // 89 diferencias de 20 y 89 de 10: √((89·400 + 89·100) / 178) = √250.
      // Si se restara 820 → 1000 a través del hueco, saldría mucho mayor.
      expect(s.hrvRmssd, 15.81);
    });
  });

  group('Serie con huecos', () {
    test('los tramos de mala señal no generan punto y t salta', () {
      final a = nuevo();
      for (var i = 0; i < 90; i++) {
        a.agregar(alterno(i, 800, 820));
      }
      for (var i = 0; i < 10; i++) {
        a.agregar(seg(dedo: false)); // segundos 90-99
      }
      for (var i = 0; i < 90; i++) {
        a.agregar(alterno(i, 800, 820));
      }
      final s = a.construir(origen: OrigenSesion.simulacion);
      final ts = s.serie.map((p) => p.t).toList();
      expect(ts.contains(90), isFalse);
      expect(ts.contains(95), isFalse);
      expect(ts.contains(85), isTrue);
      expect(ts.contains(100), isTrue);
      expect(s.duracionTotalSeg, 190);
      expect(s.duracionValidaSeg, 180);
      expect(s.duracionValidaSeg, lessThan(s.duracionTotalSeg));
      // t estrictamente creciente y dentro de la duración total.
      for (var i = 1; i < ts.length; i++) {
        expect(ts[i], greaterThan(ts[i - 1]));
      }
      expect(ts.last, lessThanOrEqualTo(s.duracionTotalSeg));
    });

    test('un tramo con 4 de 5 segundos válidos tiene punto; con 3 no', () {
      final a = nuevo();
      // Tramo 0-4: el segundo 2 es malo (4 válidos). Tramo 5-9: 7 y 8 malos (3 válidos).
      for (var i = 0; i < 10; i++) {
        final malo = i == 2 || i == 7 || i == 8;
        a.agregar(malo ? seg(dedo: false) : alterno(i, 800, 820));
      }
      for (var i = 0; i < objetivo; i++) {
        a.agregar(alterno(i, 800, 820));
      }
      final ts = a.construir(origen: OrigenSesion.simulacion).serie.map((p) => p.t).toList();
      expect(ts.contains(0), isTrue);
      expect(ts.contains(5), isFalse);
    });

    test('cabe en el máximo de 360 puntos del backend', () {
      expect(ConfigMedicion.topeTotalSeg / ConfigMedicion.intervaloSerieSeg, lessThanOrEqualTo(360));
    });
  });

  group('Resumen', () {
    test('min ≤ promedio ≤ max, enteros donde la tabla es entera, índice de calidad', () {
      final a = nuevo();
      for (var i = 0; i < 20; i++) {
        a.agregar(seg(dedo: false));
      }
      for (var i = 0; i < objetivo; i++) {
        a.agregar(seg(rr: [i.isEven ? 800 : 820], bpm: 70 + (i % 11), spo2: 95 + (i % 5)));
      }
      final s = a.construir(origen: OrigenSesion.simulacion);
      expect(s.bpmMin, 70);
      expect(s.bpmMax, 80);
      expect(s.bpmPromedio, inInclusiveRange(s.bpmMin, s.bpmMax));
      expect(s.spo2Min, 95);
      expect(s.spo2Max, 99);
      expect(s.spo2Promedio, inInclusiveRange(s.spo2Min, s.spo2Max));
      expect(s.indiceCalidad, 0.9); // 180 / 200
      expect(s.duracionValidaSeg, greaterThanOrEqualTo(120)); // mínimo del backend
    });
  });

  group('Cuerpo de POST /api/sesiones', () {
    late Map<String, dynamic> json;

    setUp(() {
      final a = nuevo();
      for (var i = 0; i < objetivo; i++) {
        a.agregar(alterno(i, 800, 815));
      }
      json = a.construir(origen: OrigenSesion.simulacion).toJson();
    });

    test('lista cerrada de campos, sin paciente_id', () {
      expect(json.keys.toSet(), {
        'fecha_inicio', 'duracion_total_seg', 'duracion_valida_seg',
        'hrv_rmssd', 'hrv_min', 'hrv_max',
        'bpm_promedio', 'bpm_min', 'bpm_max',
        'spo2_promedio', 'spo2_min', 'spo2_max',
        'indice_calidad', 'serie', 'origen',
      });
      expect(json.containsKey('paciente_id'), isFalse);
      expect(json['origen'], 'simulacion');
    });

    test('fecha en UTC con Z', () {
      expect(json['fecha_inicio'], endsWith('Z'));
      expect(DateTime.parse(json['fecha_inicio']).isUtc, isTrue);
    });

    test('números como números (no texto) y enteros donde la tabla es entera', () {
      for (final campo in ['duracion_total_seg', 'duracion_valida_seg', 'bpm_min', 'bpm_max', 'spo2_min', 'spo2_max']) {
        expect(json[campo], isA<int>(), reason: campo);
      }
      for (final campo in ['hrv_rmssd', 'hrv_min', 'hrv_max', 'bpm_promedio', 'spo2_promedio', 'indice_calidad']) {
        expect(json[campo], isA<num>(), reason: campo);
      }
      final punto = (json['serie'] as List).first as Map<String, dynamic>;
      expect(punto.keys.toSet(), {'t', 'bpm', 'spo2', 'hrv'});
      expect(punto['t'], isA<int>());
    });
  });

  group('LecturaCruda.fromJson', () {
    final anterior = LecturaCruda(bpm: 70, spo2: 97, hrv: 40);

    test('lee rr, dedo y estable cuando vienen', () {
      final l = LecturaCruda.fromJson(
        {'bpm': 72, 'spo2': 98, 'rr': [810, 830.0], 'dedo': false, 'estable': false},
        anterior: anterior,
      );
      expect(l.rr, [810, 830]);
      expect(l.dedo, isFalse);
      expect(l.estable, isFalse);
    });

    test('firmware actual (sin esos campos) conserva los valores por defecto', () {
      final l = LecturaCruda.fromJson({'bpm': 72}, anterior: anterior);
      expect(l.rr, isEmpty);
      expect(l.dedo, isTrue);
      expect(l.estable, isTrue);
      expect(l.spo2, 97);
    });
  });
}
