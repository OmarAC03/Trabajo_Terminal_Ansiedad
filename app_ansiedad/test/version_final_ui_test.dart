import 'package:app_ansiedad/contenido/gad7_textos.dart';
import 'package:app_ansiedad/contenido/privacidad_textos.dart';
import 'package:app_ansiedad/medicion/estado_sensor.dart';
import 'package:app_ansiedad/screens/consentimiento_screen.dart';
import 'package:app_ansiedad/screens/registro_screen.dart';
import 'package:app_ansiedad/ui/app_colors.dart';
import 'package:app_ansiedad/ui/boton_medir.dart';
import 'package:app_ansiedad/ui/tarjeta_gad7.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget w, {bool sinAnimaciones = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: sinAnimaciones),
        child: Scaffold(body: SingleChildScrollView(child: w)),
      ),
    );

/// Contraste WCAG entre dos colores opacos.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final claro = la > lb ? la : lb, oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  group('Registro: aviso A y dos casillas', () {
    // Pantalla alta: el formulario cabe completo y los toques no dependen del scroll.
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 9000);
      binding.platformDispatcher.views.first.devicePixelRatio = 1;
    });
    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    Future<void> llenarCampos(WidgetTester tester) async {
      final campos = find.byType(EditableText);
      await tester.enterText(campos.at(0), 'PRUEBA - Registro');
      await tester.enterText(campos.at(1), 'prueba.registro@example.com');
      await tester.enterText(campos.at(2), 'secreta123');
    }

    Future<void> tocarRegistrarme(WidgetTester tester) async {
      final boton = find.text('Registrarme');
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pump();
    }

    Future<void> marcar(WidgetTester tester, String texto) async {
      final casilla = find.text(texto);
      await tester.ensureVisible(casilla);
      await tester.pumpAndSettle();
      await tester.tap(casilla);
      await tester.pump();
    }

    testWidgets('muestra A completo, el enlace a B, las dos casillas sin marcar y el enlace a C', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroScreen()));
      expect(find.text(TextosPrivacidad.tituloAviso), findsOneWidget);
      for (final b in TextosPrivacidad.avisoSimplificado) {
        final w = find.byWidgetPredicate((w) =>
            (w is Text && (w.data == b.texto || w.data == b.plano)) ||
            (w is TextoConNegritas && w.texto == b.texto));
        expect(w, findsWidgets, reason: b.plano);
      }
      expect(find.text(TextosPrivacidad.leerCompleto), findsOneWidget);
      expect(find.text(TextosPrivacidad.leerConsentimiento), findsOneWidget);
      final casillas = tester.widgetList<CasillaPrivacidad>(find.byType(CasillaPrivacidad)).toList();
      expect(casillas.map((c) => c.texto), [TextosPrivacidad.casillaAviso, TextosPrivacidad.casillaConsentimiento]);
      expect(casillas.every((c) => !c.valor), isTrue);
    });

    testWidgets('sin ninguna casilla no deja registrarse', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroScreen()));
      await llenarCampos(tester);
      await tocarRegistrarme(tester);
      expect(find.text(TextosPrivacidad.faltaAceptarRegistro), findsOneWidget);
    });

    testWidgets('solo con el aviso no deja registrarse', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroScreen()));
      await llenarCampos(tester);
      await marcar(tester, TextosPrivacidad.casillaAviso);
      await tocarRegistrarme(tester);
      expect(find.text(TextosPrivacidad.faltaAceptarRegistro), findsOneWidget);
    });

    testWidgets('solo con el consentimiento no deja registrarse', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroScreen()));
      await llenarCampos(tester);
      await marcar(tester, TextosPrivacidad.casillaConsentimiento);
      await tocarRegistrarme(tester);
      expect(find.text(TextosPrivacidad.faltaAceptarRegistro), findsOneWidget);
    });

    testWidgets('el enlace de la casilla 2 abre el consentimiento informado (C)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistroScreen()));
      final enlace = find.text(TextosPrivacidad.leerConsentimiento);
      await tester.ensureVisible(enlace);
      await tester.tap(enlace);
      await tester.pumpAndSettle();
      expect(find.byType(ConsentimientoInformadoScreen), findsOneWidget);
    });
  });

  group('Botón de medir', () {
    testWidgets('listo: habilitado, con la leyenda y el anillo', (tester) async {
      var toques = 0;
      await tester.pumpWidget(_app(BotonMedir(habilitado: true, motivo: 'Enciende el sensor', onTap: () => toques++)));
      expect(find.text(BotonMedir.leyenda), findsOneWidget);
      expect(find.text('Enciende el sensor'), findsNothing);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(toques, 1);
    });

    testWidgets('no listo: deshabilitado y con el motivo visible', (tester) async {
      var toques = 0;
      await tester.pumpWidget(_app(BotonMedir(habilitado: false, motivo: 'Conectando…', onTap: () => toques++)));
      expect(find.text('Conectando…'), findsOneWidget);
      expect(find.text(BotonMedir.leyenda), findsNothing);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
      expect(toques, 0);
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.onTap, isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con disableAnimations no hay anillo que pulse', (tester) async {
      await tester.pumpWidget(_app(BotonMedir(habilitado: true, motivo: '', onTap: () {}), sinAnimaciones: true));
      expect(find.text(BotonMedir.leyenda), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('el motivo solo habla de la conexión', () {
      expect(motivoNoListo(FuenteLecturas.sensor, EstadoSensor.buscando), 'Conectando…');
      expect(motivoNoListo(FuenteLecturas.sensor, EstadoSensor.verificando), 'Conectando…');
      expect(motivoNoListo(FuenteLecturas.sensor, EstadoSensor.sinPermisos), 'Activa el Bluetooth');
      expect(motivoNoListo(FuenteLecturas.sensor, EstadoSensor.perdido), 'Enciende el sensor');
      expect(motivoNoListo(FuenteLecturas.sensor, EstadoSensor.error), 'Enciende el sensor');
      for (final e in EstadoSensor.values) {
        final m = motivoNoListo(FuenteLecturas.sensor, e).toLowerCase();
        for (final prohibido in ['normal', 'elevad', 'alto', 'ansiedad', 'banda']) {
          expect(m, isNot(contains(prohibido)), reason: '$e: $m');
        }
      }
    });
  });

  group('Tarjeta del GAD-7', () {
    testWidgets('con disableAnimations se ve con la etiqueta "Nuevo" y sin animación', (tester) async {
      await tester.pumpWidget(_app(TarjetaGad7(onTap: () {}), sinAnimaciones: true));
      expect(find.text(TarjetaGad7.etiquetaNuevo), findsOneWidget);
      expect(find.text(TextosGad7.tarjetaTitulo), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.descendant(of: find.byType(TarjetaGad7), matching: find.byType(ScaleTransition)), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con animaciones entra en ~400 ms y la etiqueta pulsa', (tester) async {
      var toques = 0;
      await tester.pumpWidget(_app(TarjetaGad7(onTap: () => toques++)));
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      expect(find.descendant(of: find.byType(TarjetaGad7), matching: find.byType(ScaleTransition)), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.tap(find.text(TextosGad7.tarjetaBoton));
      expect(toques, 1);
    });

    test('textos sin resultados ni puntajes', () {
      final t = '${TextosGad7.tarjetaTitulo} ${TextosGad7.tarjetaDetalle} ${TextosGad7.tarjetaBoton} '
              '${TarjetaGad7.etiquetaNuevo}'
          .toLowerCase();
      for (final p in ['puntaje', 'resultado', 'severidad', 'leve', 'moderad', 'grave', 'normal']) {
        expect(t, isNot(contains(p)), reason: p);
      }
    });

    test('colores morados con contraste AA y sin rojo ni ámbar', () {
      expect(_contraste(AppColors.cuestionarioTexto, AppColors.cuestionarioFondo), greaterThanOrEqualTo(4.5));
      expect(_contraste(AppColors.cuestionarioTextoSuave, AppColors.cuestionarioFondo), greaterThanOrEqualTo(4.5));
      expect(_contraste(Colors.white, AppColors.acentoCuestionario), greaterThanOrEqualTo(4.5));
      for (final c in [AppColors.acentoCuestionario, AppColors.cuestionarioFondo, AppColors.cuestionarioTexto]) {
        expect(c, isNot(anyOf(AppColors.altos, AppColors.elevados, AppColors.guia)));
      }
    });
  });
}
