import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/contenido/gad7_textos.dart';

/// Protege el texto del instrumento (gad7-es-v1) contra cambios accidentales y
/// revisa que ningún texto que ve el paciente hable del resultado.
void main() {
  group('el instrumento es EXACTAMENTE gad7-es-v1', () {
    test('versión', () => expect(TextosGad7.version, 'gad7-es-v1'));

    test('encabezado', () {
      expect(
        TextosGad7.encabezado,
        'Durante las últimas 2 semanas, ¿con qué frecuencia le han molestado los siguientes problemas?',
      );
    });

    test('los 7 ítems, en orden', () {
      expect(TextosGad7.items, [
        'Sentirse nervioso, ansioso o muy tenso',
        'No poder detenerse o controlar la preocupación',
        'Preocuparse demasiado por cosas diferentes',
        'Dificultad para relajarse',
        'Ser tan inquieto que es difícil quedarse quieto',
        'Molestarse o irritarse con facilidad',
        'Sentir miedo, como si algo horrible pudiera suceder',
      ]);
    });

    test('las 4 opciones con sus valores 0–3', () {
      expect(TextosGad7.opciones.map((o) => '${o.valor}:${o.texto}').toList(), [
        '0:De nada',
        '1:Varios días',
        '2:Más de la mitad de los días',
        '3:Casi todos los días',
      ]);
    });

    test('pregunta de dificultad y sus opciones', () {
      expect(
        TextosGad7.preguntaDificultad,
        'Si marcó cualquier problema, ¿qué tan difícil le han hecho estos problemas para hacer su trabajo, '
        'ocuparse de las cosas en casa, o llevarse bien con otras personas?',
      );
      expect(TextosGad7.opcionesDificultad.map((o) => '${o.valor}:${o.texto}').toList(), [
        '0:No es nada difícil',
        '1:Algo difícil',
        '2:Muy difícil',
        '3:Extremadamente difícil',
      ]);
    });
  });

  group('regla de oro: los textos de la app nunca hablan del resultado', () {
    final textosApp = <String, String>{
      'titulo': TextosGad7.titulo,
      'tarjetaTitulo': TextosGad7.tarjetaTitulo,
      'tarjetaDetalle': TextosGad7.tarjetaDetalle,
      'tarjetaBoton': TextosGad7.tarjetaBoton,
      'introTitulo': TextosGad7.introTitulo,
      for (var i = 0; i < TextosGad7.introPuntos.length; i++) 'introPuntos[$i]': TextosGad7.introPuntos[i],
      'comenzar': TextosGad7.comenzar,
      'omitirDificultad': TextosGad7.omitirDificultad,
      'enviar': TextosGad7.enviar,
      'enviando': TextosGad7.enviando,
      'salirTitulo': TextosGad7.salirTitulo,
      'salirTexto': TextosGad7.salirTexto,
      'graciasTitulo': TextosGad7.graciasTitulo,
      'graciasTexto': TextosGad7.graciasTexto,
      'yaGuardadoTexto': TextosGad7.yaGuardadoTexto,
      'listo': TextosGad7.listo,
      'apoyo': TextosGad7.apoyo,
      'disclaimer': disclaimerGad7,
    };

    final prohibidas = RegExp(
      r'puntaje|puntos|severidad|resultado|m[ií]nima|\bleve|moderad|grave|normal|elevad|\baltos?\b|'
      r'ansiedad (alta|baja)|te fue|vas bien|vas mal|mejor|peor',
      caseSensitive: false,
    );

    for (final e in textosApp.entries) {
      test(e.key, () => expect(e.value, isNot(contains(prohibidas)), reason: e.value));
    }

    test('sin números salvo "2 semanas", "2 minutos" y "7 preguntas"', () {
      for (final e in textosApp.entries) {
        final limpio = e.value.replaceAll(RegExp(r'\b(2 semanas|2 minutos|7 preguntas)\b'), '');
        expect(limpio, isNot(contains(RegExp(r'\d'))), reason: '${e.key}: ${e.value}');
      }
    });

    test('el mensaje de apoyo NO publica un teléfono sin verificar', () {
      expect(TextosGad7.apoyo, isNot(contains(RegExp(r'\d'))));
      expect(TextosGad7.apoyoLinea, isNull, reason: 'Solo se activa cuando Omar verifique el número oficial.');
    });
  });
}
