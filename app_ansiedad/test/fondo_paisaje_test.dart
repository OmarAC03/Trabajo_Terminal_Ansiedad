import 'dart:math' as math;
import 'package:app_ansiedad/ui/app_colors.dart';
import 'package:app_ansiedad/ui/fondo_paisaje.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double canal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double contraste(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const colores = [
    PintorPaisaje.cieloArriba,
    PintorPaisaje.cieloAbajo,
    PintorPaisaje.sol,
    PintorPaisaje.colinaLejana,
    PintorPaisaje.colinaMedia,
    PintorPaisaje.colinaCercana,
  ];

  test('el texto del panel cumple contraste AA (4.5:1) sobre cualquier color del paisaje', () {
    for (final fondo in colores) {
      final panel = Color.alphaBlend(Colors.white.withValues(alpha: PanelLegible.opacidad), fondo);
      for (final texto in [AppColors.texto, AppColors.textoAyuda]) {
        expect(contraste(texto, panel), greaterThanOrEqualTo(4.5), reason: '$texto sobre $fondo');
      }
    }
  });

  testWidgets('el paisaje se dibuja detrás y el contenido queda encima', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FondoPaisaje(child: Center(child: PanelLegible(child: Text('Hola'))))),
    ));
    expect(find.text('Hola'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorPaisaje), findsOneWidget);
  });
}
