import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/medicion/calculo_sesion.dart';
import 'package:app_ansiedad/models/lectura_cruda.dart';
import 'package:app_ansiedad/models/sesion_medicion.dart';
import 'package:app_ansiedad/repositories/interprete_sensor.dart';

/// Reloj de prueba: avanza solo cuando se le pide.
class Reloj {
  DateTime ahora = DateTime(2026, 10, 22, 9);
  void avanzar(int ms) => ahora = ahora.add(Duration(milliseconds: ms));
}

/// Un paquete del contrato v1, con valores de reposo; [quitar] lo deja sin
/// ese campo y [extra] cambia o agrega campos.
String paquete(int seq, {List<int> rr = const [800], List<String> quitar = const [], Map<String, Object?> extra = const {}}) {
  final m = <String, Object?>{
    'v': 1,
    'seq': seq,
    'bpm': 75,
    'spo2': 98,
    'rr': rr,
    'dedo': true,
    'estable': true,
    ...extra,
  };
  for (final k in quitar) {
    m.remove(k);
  }
  return jsonEncode(m);
}

/// Firmware actual (antes del contrato): hrv ya calculado, sin v ni rr.
String paqueteViejo() => jsonEncode({'bpm': 75, 'spo2': 98, 'hrv': 42});

/// Intérprete ya conectado a un firmware compatible (consume el paquete 0).
(InterpreteSensor, Reloj) conectado() {
  final reloj = Reloj();
  final i = InterpreteSensor(reloj: () => reloj.ahora);
  i.procesar(paquete(0));
  reloj.avanzar(1000);
  return (i, reloj);
}

/// Dos paquetes muy seguidos (seq 1 y 2) para dejar sin crédito al intérprete:
/// el siguiente que llegue en menos de un segundo queda retenido.
void gastarCredito(InterpreteSensor i, Reloj reloj) {
  i.procesar(paquete(1));
  reloj.avanzar(100);
  i.procesar(paquete(2));
  reloj.avanzar(100);
}

bool sinDedo(LecturaCruda l) => !l.dedo && !l.estable && l.rr.isEmpty && l.bpm == 0;

void main() {
  group('paquete completo', () {
    test('el primer paquete v1 da el firmware por compatible y sale su lectura', () {
      final i = InterpreteSensor();
      expect(i.firmware, EstadoFirmware.verificando);
      final l = i.procesar(paquete(7, rr: [812, 798]))!;
      expect(i.firmware, EstadoFirmware.compatible);
      expect((l.bpm, l.spo2, l.dedo, l.estable, l.cortaCadenaRr), (75, 98, true, true, false));
      expect(l.rr, [812, 798]);
    });

    test('rr vacío es válido (en ese segundo no terminó ningún latido)', () {
      final (i, _) = conectado();
      final l = i.procesar(paquete(1, rr: []))!;
      expect(l.dedo, isTrue);
      expect(l.rr, isEmpty);
    });

    test('dedo y estable en false se respetan', () {
      final (i, _) = conectado();
      final l = i.procesar(paquete(1, extra: {'dedo': false, 'estable': false}))!;
      expect((l.dedo, l.estable), (false, false));
    });

    test('un campo extra (hrv del firmware) se ignora', () {
      final (i, _) = conectado();
      expect(i.procesar(paquete(1, extra: {'hrv': 42}))!.dedo, isTrue);
    });
  });

  group('paquete incompleto = segundo sin dedo', () {
    for (final campo in ['v', 'seq', 'bpm', 'spo2', 'rr', 'dedo', 'estable']) {
      test('sin "$campo"', () {
        final (i, _) = conectado();
        expect(sinDedo(i.procesar(paquete(1, quitar: [campo]))!), isTrue);
      });
    }

    test('tipos equivocados también (texto, decimales, rr con texto)', () {
      for (final extra in <Map<String, Object?>>[
        {'dedo': 'true'},
        {'bpm': 72.5},
        {'rr': [800, '810']},
        {'rr': 800},
        {'v': 2},
      ]) {
        final (i, _) = conectado();
        expect(sinDedo(i.procesar(paquete(1, extra: extra))!), isTrue, reason: '$extra');
      }
    });

    test('no hereda nada del paquete anterior', () {
      final (i, reloj) = conectado();
      i.procesar(paquete(1, extra: {'bpm': 90}));
      reloj.avanzar(1000);
      final l = i.procesar(paquete(2, quitar: ['bpm']))!;
      expect(l.bpm, 0);
      expect(l.dedo, isFalse);
    });

    test('una línea que no es JSON no publica nada ni rompe lo que sigue', () {
      final (i, reloj) = conectado();
      expect(i.procesar('{"v":1,"seq":1,"bp'), isNull);
      expect(i.procesar('[1,2,3]'), isNull);
      reloj.avanzar(1000);
      expect(i.procesar(paquete(1))!.dedo, isTrue);
    });
  });

  group('firmware viejo', () {
    test('3 paquetes sin v: no compatible y no sale ninguna lectura', () {
      final i = InterpreteSensor();
      expect(i.procesar(paqueteViejo()), isNull);
      expect(i.procesar(paqueteViejo()), isNull);
      expect(i.firmware, EstadoFirmware.verificando);
      expect(i.procesar(paqueteViejo()), isNull);
      expect(i.firmware, EstadoFirmware.noCompatible);
    });

    test('una vez no compatible, ni un paquete v1 lo cambia hasta reconectar', () {
      final i = InterpreteSensor();
      for (var n = 0; n < 3; n++) {
        i.procesar(paqueteViejo());
      }
      expect(i.procesar(paquete(1)), isNull);
      expect(i.firmware, EstadoFirmware.noCompatible);

      i.reiniciar(); // reconectar (por ejemplo, tras actualizar el firmware)
      expect(i.firmware, EstadoFirmware.verificando);
      expect(i.procesar(paquete(1)), isNotNull);
      expect(i.firmware, EstadoFirmware.compatible);
    });

    test('otra versión del contrato: no compatible al primer paquete', () {
      final i = InterpreteSensor();
      expect(i.procesar(paquete(1, extra: {'v': 2})), isNull);
      expect(i.firmware, EstadoFirmware.noCompatible);
    });

    test('la basura del serial no cuenta para declararlo viejo', () {
      final i = InterpreteSensor();
      for (var n = 0; n < 5; n++) {
        i.procesar('##ruido##');
      }
      expect(i.firmware, EstadoFirmware.verificando);
      expect(i.procesar(paquete(1)), isNotNull);
    });

    test('un paquete viejo suelto antes del v1 (arranque) no lo descarta', () {
      final i = InterpreteSensor();
      i.procesar(paqueteViejo());
      expect(i.procesar(paquete(1)), isNotNull);
      expect(i.firmware, EstadoFirmware.compatible);
    });
  });

  group('huecos en seq', () {
    test('seq consecutivo no corta la cadena', () {
      final (i, reloj) = conectado();
      expect(i.procesar(paquete(1))!.cortaCadenaRr, isFalse);
      reloj.avanzar(1000);
      expect(i.procesar(paquete(2))!.cortaCadenaRr, isFalse);
    });

    test('un salto (paquete perdido) corta la cadena en el siguiente', () {
      final (i, reloj) = conectado();
      i.procesar(paquete(1));
      reloj.avanzar(2000);
      expect(i.procesar(paquete(3))!.cortaCadenaRr, isTrue);
      reloj.avanzar(1000);
      expect(i.procesar(paquete(4))!.cortaCadenaRr, isFalse);
    });

    test('seq que vuelve a 0 (el ESP32 se reinició) también corta', () {
      final (i, reloj) = conectado();
      i.procesar(paquete(1));
      reloj.avanzar(1000);
      expect(i.procesar(paquete(0))!.cortaCadenaRr, isTrue);
    });

    test('el cálculo no resta RR a través del hueco', () {
      // RR 800 → (paquete perdido) → 810. Sin el corte, la diferencia 10 ms
      // entraría al RMSSD (daría 15.81); con el corte solo cuenta 810 → 830 (20 ms).
      final (i, reloj) = conectado();
      final a = AcumuladorSesion(fechaInicio: DateTime.now());
      a.agregar(i.procesar(paquete(1, rr: [800]))!);
      reloj.avanzar(2000);
      a.agregar(i.procesar(paquete(3, rr: [810]))!);
      reloj.avanzar(1000);
      a.agregar(i.procesar(paquete(4, rr: [830]))!);
      // Para tener una sesión completa, segundos válidos sin RR nuevos.
      for (var s = 5; !a.completa; s++) {
        reloj.avanzar(1000);
        a.agregar(i.procesar(paquete(s, rr: []))!);
      }
      expect(a.construir(origen: OrigenSesion.sensor).hrvRmssd, 20);
    });
  });

  group('una lectura por segundo de reloj', () {
    test('a 1 Hz con desfase normal (0.98 s / 1.02 s) no se junta nada', () {
      final (i, reloj) = conectado();
      var publicadas = 0;
      for (var s = 1; s <= 60; s++) {
        reloj.avanzar(s.isEven ? 980 : 1020);
        if (i.procesar(paquete(s)) != null) publicadas++;
      }
      expect(publicadas, 60);
    });

    test('a 2 Hz sale una lectura por segundo, con los RR de ambos paquetes', () {
      final (i, reloj) = conectado();
      final salida = <LecturaCruda>[];
      for (var s = 1; s <= 40; s++) {
        reloj.avanzar(500);
        final l = i.procesar(paquete(s, rr: [s]));
        if (l != null) salida.add(l);
      }
      // 20 s transcurridos: ~20 lecturas, no 40.
      expect(salida.length, inInclusiveRange(19, 23));
      // Ningún RR se pierde, repite ni desordena (el último puede seguir retenido).
      final rr = salida.expand((l) => l.rr).toList();
      expect(rr, List.generate(rr.length, (k) => k + 1));
      expect(rr.length, greaterThanOrEqualTo(38));
    });

    test('al juntar, dedo/estable solo si ambos paquetes los tienen', () {
      final (i, reloj) = conectado();
      gastarCredito(i, reloj);
      expect(i.procesar(paquete(3, extra: {'dedo': false})), isNull); // retenida
      reloj.avanzar(900);
      final l = i.procesar(paquete(4))!;
      expect(l.dedo, isFalse);
    });

    test('al juntar con un hueco de seq en medio, no se encadenan los RR', () {
      final (i, reloj) = conectado();
      gastarCredito(i, reloj);
      expect(i.procesar(paquete(3, rr: [700])), isNull);
      reloj.avanzar(900);
      final l = i.procesar(paquete(5, rr: [900]))!; // se perdió el 4
      expect(l.rr, [900]);
      expect(l.cortaCadenaRr, isTrue);
    });
  });
}
