import 'dart:io';
import 'package:app_ansiedad/app_config.dart';
import 'package:app_ansiedad/contenido/acerca_textos.dart';
import 'package:app_ansiedad/screens/acerca_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _envolver(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

/// Todo el texto visible del árbol.
String _textos(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? '',
    ].join(' | ');

void main() {
  group('Acerca de la app', () {
    testWidgets('no muestra la URL del servidor ni datos técnicos', (tester) async {
      await tester.pumpWidget(_envolver(SeccionAcercaApp(comprobar: () async => true)));
      await tester.pump();
      final todo = _textos(tester);
      expect(todo, isNot(contains(AppConfig.backendUrl)));
      for (final prohibido in ['http', 'onrender', 'Render', 'Supabase', 'Firebase', '/api', 'Servidor']) {
        expect(todo, isNot(contains(prohibido)), reason: prohibido);
      }
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text(AppConfig.versionApp), findsOneWidget);
    });

    testWidgets('sin respuesta del servidor dice "Sin conexión" y se puede reintentar', (tester) async {
      var ok = false;
      var llamadas = 0;
      await tester.pumpWidget(_envolver(SeccionAcercaApp(comprobar: () async {
        llamadas++;
        return ok;
      })));
      await tester.pump();
      expect(find.text('Sin conexión'), findsOneWidget);
      ok = true;
      await tester.tap(find.text('Sin conexión'));
      await tester.pump();
      expect(find.text('Conectado'), findsOneWidget);
      expect(llamadas, 2);
    });

    test('la versión visible es la de pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1);
      expect(AppConfig.versionApp, version);
    });
  });

  group('Acerca del proyecto', () {
    testWidgets('logos, título, dos párrafos y "Leer más" con el resto', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionAcercaProyecto()));
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text(TextosAcerca.titulo), findsOneWidget);
      expect(find.text(TextosAcerca.parrafos[0]), findsOneWidget);
      expect(find.text(TextosAcerca.parrafos[1]), findsOneWidget);
      expect(find.text(TextosAcerca.parrafos[2]), findsNothing);
      expect(find.text(TextosAcerca.pie), findsOneWidget);

      await tester.tap(find.text(TextosAcerca.leerMas));
      await tester.pump();
      expect(find.text(TextosAcerca.parrafos[2]), findsOneWidget);
      expect(find.text(TextosAcerca.leerMenos), findsOneWidget);
    });

    test('el texto es el entregado (fragmentos clave)', () {
      final todo = TextosAcerca.parrafos.join(' ');
      expect(TextosAcerca.parrafos, hasLength(3));
      expect(todo, startsWith('En la Escuela Superior de Cómputo, como en cualquier universidad'));
      expect(todo, contains('la ansiedad y el estrés con los que los estudiantes lidiamos día a día.'));
      expect(todo, endsWith('como cualquier otra materia.'));
      expect(TextosAcerca.pie, 'Mi Ritmo · Escuela Superior de Cómputo · Instituto Politécnico Nacional');
    });
  });
}
