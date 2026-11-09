import 'package:app_ansiedad/app_config.dart';
import 'package:app_ansiedad/providers/alerta_provider.dart';
import 'package:app_ansiedad/ui/pantalla_cargando.dart';
import 'package:app_ansiedad/ui/selector_fuente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _envolver(Widget w) => MaterialApp(home: Scaffold(backgroundColor: Colors.blue, body: Center(child: w)));

void main() {
  group('sabores de compilación', () {
    test('sin bandera (o con un valor raro) sale PILOTO; solo DEMO activa el simulador', () {
      expect(saborDesde('PILOTO'), Sabor.piloto);
      expect(saborDesde(''), Sabor.piloto);
      expect(saborDesde('loquesea'), Sabor.piloto);
      expect(saborDesde('DEMO'), Sabor.demo);
      expect(saborDesde(' demo '), Sabor.demo);
      expect(AppConfig.conSimulador(Sabor.piloto), isFalse);
      expect(AppConfig.conSimulador(Sabor.demo), isTrue);
    });

    test('las pruebas corren con la compilación por defecto: PILOTO', () {
      expect(AppConfig.sabor, Sabor.piloto);
    });

    testWidgets('PILOTO no muestra el simulador ni el selector de fuente', (tester) async {
      final alerta = AlertaProvider();
      addTearDown(alerta.dispose);
      await tester.pumpWidget(_envolver(SelectorFuente(alerta, sabor: Sabor.piloto)));
      expect(find.text('Simulación'), findsNothing);
      expect(find.text('Sensor'), findsOneWidget);
      expect(textoSinFuente(Sabor.piloto), isNot(contains('Simulación')));
    });

    testWidgets('DEMO queda como antes: Simulación y Sensor', (tester) async {
      final alerta = AlertaProvider();
      addTearDown(alerta.dispose);
      await tester.pumpWidget(_envolver(SelectorFuente(alerta, sabor: Sabor.demo)));
      expect(find.text('Simulación'), findsOneWidget);
      expect(find.text('Sensor'), findsOneWidget);
      expect(textoSinFuente(Sabor.demo), contains('Simulación'));
    });
  });

  group('pantalla de arranque', () {
    testWidgets('muestra la mascota y "Cargando"; si tarda, explica la espera', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PantallaCargando(avisoTras: Duration(seconds: 8))));
      expect(find.text(PantallaCargando.texto), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final espera = find.text(PantallaCargando.textoEspera);
      double opacidad() => tester.widget<AnimatedOpacity>(find.ancestor(of: espera, matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacidad(), 0);
      await tester.pump(const Duration(seconds: 9));
      expect(opacidad(), 1);
      await tester.pumpWidget(const SizedBox()); // desmonta: cancela la animación
    });
  });
}
