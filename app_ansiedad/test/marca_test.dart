import 'dart:io';
import 'package:app_ansiedad/contenido/acerca_textos.dart';
import 'package:app_ansiedad/contenido/marca.dart';
import 'package:app_ansiedad/notificaciones/recordatorio_gad7.dart';
import 'package:app_ansiedad/ui/estructura_acceso.dart';
import 'package:app_ansiedad/ui/pantalla_cargando.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Todo el texto visible del árbol.
String _textos(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? '',
    ].join(' | ');

/// Literales de texto ('...' o "...") de un archivo fuente.
Iterable<String> _literales(String fuente) =>
    RegExp(r"'([^'\\]|\\.)*'" '|' r'"([^"\\]|\\.)*"').allMatches(fuente).map((m) => m.group(0)!);

const _prohibidos = ['ansiedad', 'Monitor ESCOM', 'Trabajo Terminal'];

void main() {
  test('nombre, lema y mascota', () {
    expect(Marca.nombreApp, 'Mi Ritmo');
    expect(Marca.lema, 'Tu ritmo, acompañado.');
    expect(Marca.nombreMascota, 'Riti');
    expect(Marca.fraseMascota, 'Vamos a tu ritmo.');
    expect(PantallaCargando.texto, 'Riti está preparando todo…');
  });

  test('el nombre bajo el ícono es "Mi Ritmo" y el applicationId no cambia', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="Mi Ritmo"'));
    final gradle = File('android/app/build.gradle.kts').existsSync()
        ? File('android/app/build.gradle.kts').readAsStringSync()
        : File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId = "com.example.app_ansiedad"'));
  });

  test('el título de la app no dice "ansiedad"', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('title: Marca.nombreApp'));
    for (final p in _prohibidos) {
      expect(Marca.nombreApp.toLowerCase(), isNot(contains(p.toLowerCase())));
      expect(Marca.lema.toLowerCase(), isNot(contains(p.toLowerCase())));
      expect(tituloRecordatorio.toLowerCase(), isNot(contains(p.toLowerCase())));
      expect(TextosAcerca.pie.toLowerCase(), isNot(contains(p.toLowerCase())));
    }
  });

  testWidgets('la marca del login y el registro dice "Mi Ritmo" + el lema y nada de "ansiedad"', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EstructuraAcceso(titulo: 'Iniciar sesión', subtitulo: 'Ingresa a tu cuenta', formulario: SizedBox()),
    ));
    final todo = _textos(tester);
    expect(find.text(Marca.nombreApp), findsOneWidget);
    expect(find.text(Marca.lema), findsOneWidget);
    for (final p in _prohibidos) {
      expect(todo.toLowerCase(), isNot(contains(p.toLowerCase())), reason: p);
    }
  });

  test('ningún texto del login ni del registro dice "ansiedad"', () {
    for (final archivo in ['lib/screens/login_screen.dart', 'lib/screens/registro_screen.dart']) {
      for (final literal in _literales(File(archivo).readAsStringSync())) {
        if (literal.contains('package:') || literal.contains('/')) continue; // imports y rutas
        for (final p in _prohibidos) {
          expect(literal.toLowerCase(), isNot(contains(p.toLowerCase())), reason: '$archivo: $literal');
        }
      }
    }
  });

  testWidgets('la pantalla de carga muestra el nombre, el lema y a Riti', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaCargando()));
    expect(find.text(Marca.nombreApp), findsOneWidget);
    expect(find.text(Marca.lema), findsOneWidget);
    expect(find.text('Riti está preparando todo…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
