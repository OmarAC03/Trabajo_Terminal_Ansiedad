import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/medicion/mensajes_mascota.dart';
import 'package:app_ansiedad/models/calibracion.dart';

Calibracion cal(
  EtapaBase etapa, {
  int dia = 3,
  int dias = 2,
  bool medidoHoy = false,
  bool vencido = false,
}) =>
    Calibracion(
      origen: 'simulacion',
      etapa: etapa,
      etapaManana: etapa,
      diaCalibracion: dia,
      diasObjetivo: 7,
      diasConMedicion: dias,
      medidoHoy: medidoHoy,
      hayHistorialVencido: vencido,
    );

/// Todas las situaciones posibles, para revisar la regla de oro sobre cada
/// mensaje que la mascota puede decir.
List<MensajeMascota> todosLosMensajes() {
  final mensajes = <MensajeMascota>[mensajeMalaSenal, mensajeNoCompletada];
  for (final sin in [true, false]) {
    mensajes.add(mensajeInicio(sinMediciones: sin, calibracion: null) ??
        const MensajeMascota('ninguno', ''));
  }
  for (final etapa in EtapaBase.values) {
    for (final dia in [1, 2, 3, 4, 6, 7]) {
      for (final medido in [true, false]) {
        for (final vencido in [true, false]) {
          final c = cal(etapa, dia: dia, dias: medido ? dia : dia - 1, medidoHoy: medido, vencido: vencido);
          mensajes.add(mensajeInicio(sinMediciones: false, calibracion: c)!);
          for (final motivo in [null, ...MotivoSinComparar.values]) {
            for (final ya in [true, false]) {
              mensajes.add(mensajeResultado(
                evaluacion: EvaluacionSesion(etapa: etapa, motivo: motivo),
                calibracion: c,
                yaHabiaMedidoHoy: ya,
              ));
            }
          }
        }
      }
    }
  }
  mensajes.add(mensajeResultado());
  return mensajes.where((m) => m.texto.isNotEmpty).toList();
}

void main() {
  group('Inicio', () {
    test('sin mediciones: bienvenida', () {
      final m = mensajeInicio(sinMediciones: true)!;
      expect(m.avatar, 'avatar_saludando.png');
      expect(m.texto, startsWith('¡Hola!'));
    });

    test('con mediciones pero sin calibración: sin mensaje (Inicio como antes de M3)', () {
      expect(mensajeInicio(sinMediciones: false, calibracion: null), isNull);
    });

    test('calibrando: aprende el ritmo; si ya midió hoy, lo celebra', () {
      final antes = mensajeInicio(sinMediciones: false, calibracion: cal(EtapaBase.calibrando, dia: 2, dias: 1))!;
      expect(antes.avatar, 'avatar_pensativo.png');
      expect(antes.texto, 'Estoy aprendiendo cómo es tu ritmo. Hoy sería tu día 2 de 7.');

      final despues = mensajeInicio(
          sinMediciones: false, calibracion: cal(EtapaBase.calibrando, dia: 2, dias: 2, medidoHoy: true))!;
      expect(despues.avatar, 'avatar_feliz.png');
      expect(despues.texto, '¡Medición de hoy lista! Vamos en el día 2 de 7. Mañana seguimos.');
    });

    test('volvió tras más de 30 días: bienvenida de regreso', () {
      final m = mensajeInicio(
          sinMediciones: false, calibracion: cal(EtapaBase.calibrando, dia: 1, dias: 0, vencido: true))!;
      expect(m.avatar, 'avatar_guinando.png');
      expect(m.texto, contains('día 1 de 7'));
    });

    test('preliminar y consolidada', () {
      expect(mensajeInicio(sinMediciones: false, calibracion: cal(EtapaBase.preliminar, dia: 5, dias: 4))!.texto,
          'Ya te voy conociendo. Hoy sería tu día 5 de 7.');
      expect(
          mensajeInicio(
                  sinMediciones: false, calibracion: cal(EtapaBase.preliminar, dia: 5, dias: 5, medidoHoy: true))!
              .texto,
          '¡Día 5 de 7 completado! Cada día me ayuda a conocerte mejor.');
      expect(mensajeInicio(sinMediciones: false, calibracion: cal(EtapaBase.consolidada, dia: 7, dias: 9))!.avatar,
          'avatar_sereno.png');
      expect(
          mensajeInicio(
                  sinMediciones: false, calibracion: cal(EtapaBase.consolidada, dia: 7, dias: 9, medidoHoy: true))!
              .avatar,
          'avatar_genial.png');
    });
  });

  group('Resultado', () {
    EvaluacionSesion ev(EtapaBase e, [MotivoSinComparar? m]) => EvaluacionSesion(etapa: e, motivo: m);

    test('primera medición; la segunda del día 1 ya no es "primera"', () {
      final c = cal(EtapaBase.calibrando, dia: 1, dias: 1, medidoHoy: true);
      final primera = mensajeResultado(evaluacion: ev(EtapaBase.calibrando, MotivoSinComparar.calibrando), calibracion: c);
      expect(primera.avatar, 'avatar_celebrando.png');
      expect(primera.texto, '¡Tu primera medición! Hoy empiezo a conocer tu ritmo: día 1 de 7.');

      final segunda = mensajeResultado(
          evaluacion: ev(EtapaBase.calibrando, MotivoSinComparar.calibrando), calibracion: c, yaHabiaMedidoHoy: true);
      expect(segunda.texto, '¡Bien hecho! Día 1 de 7: sigo aprendiendo cómo es tu ritmo.');
    });

    test('preliminar y consolidada celebran el hábito', () {
      expect(
          mensajeResultado(evaluacion: ev(EtapaBase.preliminar), calibracion: cal(EtapaBase.preliminar, dia: 4, dias: 4)).texto,
          '¡Una medición más! Día 4 de 7: ya te voy conociendo.');
      final c = mensajeResultado(evaluacion: ev(EtapaBase.consolidada), calibracion: cal(EtapaBase.consolidada, dia: 7));
      expect(c.avatar, 'avatar_genial.png');
      expect(c.texto, '¡Hábito cumplido! Cada medición me ayuda a acompañarte mejor.');
    });

    test('calidad baja: texto aprobado, mascota serena (gana a cualquier etapa)', () {
      final m = mensajeResultado(
          evaluacion: ev(EtapaBase.consolidada, MotivoSinComparar.calidadBaja), calibracion: cal(EtapaBase.consolidada));
      expect(m.avatar, 'avatar_sereno.png');
      expect(m.texto, startsWith('¡Gracias por medir! Tu medición quedó guardada. Esta vez la señal tuvo varias pausas'));
    });

    test('sin evaluación ni calibración (el backend no las calculó): mensaje genérico', () {
      expect(mensajeResultado().texto, '¡Bien hecho! Tu medición quedó guardada.');
    });
  });

  group('Mala señal', () {
    test('textos calmados y sin género', () {
      expect(mensajeMalaSenal.avatar, 'avatar_meditando.png');
      expect(mensajeMalaSenal.texto, startsWith('Con calma, aquí espero.'));
      expect(mensajeNoCompletada.avatar, 'avatar_sereno.png');
      for (final m in [mensajeMalaSenal, mensajeNoCompletada]) {
        expect(m.texto.toLowerCase(), isNot(contains('tranquilo')));
      }
    });
  });

  group('Progreso', () {
    test('puntos solo mientras no se consolida; los rellenos son los días que ya cuentan', () {
      expect(mostrarProgreso(cal(EtapaBase.calibrando)), isTrue);
      expect(mostrarProgreso(cal(EtapaBase.preliminar)), isTrue);
      expect(mostrarProgreso(cal(EtapaBase.consolidada)), isFalse);
      expect(diasContados(cal(EtapaBase.preliminar, dias: 4)), 4);
      expect(diasContados(cal(EtapaBase.consolidada, dias: 12)), 7);
    });
  });

  group('REGLA DE ORO: ningún mensaje de la mascota juzga ni da valores', () {
    final mensajes = todosLosMensajes();

    test('se revisaron todas las situaciones', () {
      expect(mensajes.length, greaterThan(100));
    });

    test('sin etiquetas del estado ni palabras de juicio', () {
      final prohibidas = RegExp(
        r'\b(normal|normales|elevad\w*|alto|altos|alta|altas|bajo|bajos|baja|bajas|ansiedad|ansios\w*|'
        r'banda|rango|estado|mal|peor|mejor[ae]s?\s+que|preocup\w*|riesgo|alerta)\b',
        caseSensitive: false,
        unicode: true,
      );
      for (final m in mensajes) {
        expect(prohibidas.hasMatch(m.texto), isFalse, reason: 'Texto prohibido en: $m');
      }
    });

    test('sin números de HRV/FC: el único número permitido es el de "día X de 7"', () {
      for (final m in mensajes) {
        final sinDia = m.texto.replaceAll(RegExp(r'[Dd]ía \d+ de \d+'), '');
        expect(RegExp(r'\d').hasMatch(sinDia), isFalse, reason: 'Número en: $m');
        expect(RegExp(r'\b(ms|lpm|lat/min|hrv|rmssd|fc|frecuencia)\b', caseSensitive: false).hasMatch(m.texto),
            isFalse,
            reason: 'Unidad o métrica en: $m');
      }
    });

    test('sin la expresión "preocupado" en ninguna situación', () {
      for (final m in mensajes) {
        expect(m.avatar, isNot(contains('preocupado')), reason: '$m');
      }
    });

    test('cada avatar existe en assets/mascota con sus variantes 2.0x y 3.0x', () {
      for (final avatar in mensajes.map((m) => m.avatar).toSet()) {
        for (final carpeta in ['', '2.0x/', '3.0x/']) {
          expect(File('assets/mascota/$carpeta$avatar').existsSync(), isTrue, reason: 'falta $carpeta$avatar');
        }
      }
    });
  });
}
