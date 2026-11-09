import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fondo tranquilo de Ejercicios (versión final, punto 4): cielo claro, un sol
/// tenue y colinas en capas, dibujado en código (sin imágenes ni licencias).
/// Los colores son suaves a propósito: el texto va en tarjetas blancas y los
/// textos sueltos sobre un panel blanco translúcido ([PanelLegible]).
class FondoPaisaje extends StatelessWidget {
  final Widget child;
  const FondoPaisaje({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: PintorPaisaje()))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class PintorPaisaje extends CustomPainter {
  const PintorPaisaje();

  static const cieloArriba = Color(0xFFDCEBFA);
  static const cieloAbajo = Color(0xFFF5F9FC);
  static const sol = Color(0xFFFFE9B8);
  static const colinaLejana = Color(0xFFD3E4F2);
  static const colinaMedia = Color(0xFFC6E2D6);
  static const colinaCercana = Color(0xFFAED6C1);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cieloArriba, cieloAbajo],
        ).createShader(rect),
    );

    // Sol con halo.
    final centroSol = Offset(w * 0.78, h * 0.50);
    canvas.drawCircle(centroSol, w * 0.20, Paint()..color = sol.withValues(alpha: 0.35));
    canvas.drawCircle(centroSol, w * 0.11, Paint()..color = sol.withValues(alpha: 0.9));

    _colina(canvas, size, base: 0.66, amplitud: 0.05, fase: 0.0, ondas: 1.3, color: colinaLejana);
    _colina(canvas, size, base: 0.75, amplitud: 0.045, fase: 1.7, ondas: 1.6, color: colinaMedia);
    _colina(canvas, size, base: 0.85, amplitud: 0.04, fase: 3.1, ondas: 1.1, color: colinaCercana);
  }

  /// Una franja ondulada desde [base] (fracción de la altura) hasta abajo.
  void _colina(Canvas canvas, Size size,
      {required double base, required double amplitud, required double fase, required double ondas, required Color color}) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h);
    const pasos = 48;
    for (var i = 0; i <= pasos; i++) {
      final x = w * i / pasos;
      final y = h * (base - amplitud * math.sin(fase + ondas * math.pi * i / pasos));
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PintorPaisaje oldDelegate) => false;
}

/// Panel blanco translúcido para textos que no van en tarjeta.
class PanelLegible extends StatelessWidget {
  final Widget child;
  const PanelLegible({super.key, required this.child});

  /// Opacidad del blanco: con ella el texto oscuro mantiene el contraste AA
  /// sobre cualquier punto del paisaje.
  static const double opacidad = 0.88;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacidad),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
