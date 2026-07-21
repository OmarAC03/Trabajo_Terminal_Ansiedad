import 'package:flutter/material.dart';

/// Catálogo de avatares disponibles. El "id" es lo que se guarda en
/// `photoURL` de Firebase Auth con el prefijo "avatar:" (ej. "avatar:zorro").
enum TipoAvatar { zorro, gato, buho, panda, conejo, oso }

extension TipoAvatarInfo on TipoAvatar {
  String get id => toString().split('.').last;

  String get nombre {
    switch (this) {
      case TipoAvatar.zorro:
        return "Zorro";
      case TipoAvatar.gato:
        return "Gato";
      case TipoAvatar.buho:
        return "Búho";
      case TipoAvatar.panda:
        return "Panda";
      case TipoAvatar.conejo:
        return "Conejo";
      case TipoAvatar.oso:
        return "Oso";
    }
  }

  Color get colorFondo {
    switch (this) {
      case TipoAvatar.zorro:
        return const Color(0xFFFF9F5A);
      case TipoAvatar.gato:
        return const Color(0xFFB6A6E9);
      case TipoAvatar.buho:
        return const Color(0xFFC79A63);
      case TipoAvatar.panda:
        return const Color(0xFFDDE3EA);
      case TipoAvatar.conejo:
        return const Color(0xFFFFB6C9);
      case TipoAvatar.oso:
        return const Color(0xFFB48A63);
    }
  }

  static TipoAvatar? desdeId(String? id) {
    if (id == null) return null;
    for (final t in TipoAvatar.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Extrae el TipoAvatar guardado en el `photoURL` de Firebase, si existe.
/// Formato esperado: "avatar:zorro". Si el campo trae otra cosa (o es nulo,
/// como en cuentas viejas antes de esta función), devuelve null.
TipoAvatar? avatarDesdePhotoUrl(String? photoUrl) {
  if (photoUrl == null || !photoUrl.startsWith('avatar:')) return null;
  return TipoAvatarInfo.desdeId(photoUrl.substring('avatar:'.length));
}

String avatarAPhotoUrl(TipoAvatar tipo) => 'avatar:${tipo.id}';

// =============================================================
// WIDGET: círculo con el avatar dibujado adentro
// =============================================================
class AnimalAvatar extends StatelessWidget {
  final TipoAvatar tipo;
  final double size;

  const AnimalAvatar({super.key, required this.tipo, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tipo.colorFondo),
      child: CustomPaint(painter: _AnimalPainter(tipo)),
    );
  }
}

// =============================================================
// SELECTOR: hoja inferior con la cuadrícula de opciones
// =============================================================
Future<TipoAvatar?> mostrarSelectorAvatar(BuildContext context, {TipoAvatar? actual}) {
  return showModalBottomSheet<TipoAvatar>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Elige tu avatar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: TipoAvatar.values.map((tipo) {
                final seleccionado = tipo == actual;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, tipo),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: seleccionado ? const Color(0xFF1E6AFB) : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: AnimalAvatar(tipo: tipo, size: 64),
                      ),
                      const SizedBox(height: 6),
                      Text(tipo.nombre, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

// =============================================================
// PAINTER: dibuja cada animal con formas geométricas simples
// =============================================================
class _AnimalPainter extends CustomPainter {
  final TipoAvatar tipo;
  _AnimalPainter(this.tipo);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    switch (tipo) {
      case TipoAvatar.zorro:
        _dibujarZorro(canvas, c, r);
        break;
      case TipoAvatar.gato:
        _dibujarGato(canvas, c, r);
        break;
      case TipoAvatar.buho:
        _dibujarBuho(canvas, c, r);
        break;
      case TipoAvatar.panda:
        _dibujarPanda(canvas, c, r);
        break;
      case TipoAvatar.conejo:
        _dibujarConejo(canvas, c, r);
        break;
      case TipoAvatar.oso:
        _dibujarOso(canvas, c, r);
        break;
    }
  }

  void _oreja(Canvas canvas, Offset base, double r, double dx, Paint paint, {double ancho = 0.42, double alto = 0.5}) {
    final path = Path()
      ..moveTo(base.dx + dx * r * 0.75, base.dy - r * 0.35)
      ..lineTo(base.dx + dx * r * (0.75 + ancho), base.dy - r * (0.35 + alto))
      ..lineTo(base.dx + dx * r * (0.75 - ancho * 0.3), base.dy - r * 0.75)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _ojos(Canvas canvas, Offset c, double r, {double separacion = 0.32, double y = -0.05, double radio = 0.075, Color color = Colors.black87}) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(c.dx - r * separacion, c.dy + r * y), r * radio, paint);
    canvas.drawCircle(Offset(c.dx + r * separacion, c.dy + r * y), r * radio, paint);
  }

  void _dibujarZorro(Canvas canvas, Offset c, double r) {
    final blanco = Paint()..color = Colors.white;
    final naranjaOscuro = Paint()..color = const Color(0xFFE07A2C);

    // Orejas
    _oreja(canvas, c, r, -1, naranjaOscuro);
    _oreja(canvas, c, r, 1, naranjaOscuro);
    // Cara (círculo blanco central, tipo máscara)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.08), width: r * 1.15, height: r * 1.0),
      blanco,
    );
    // Hocico
    final hocico = Path()
      ..moveTo(c.dx - r * 0.22, c.dy + r * 0.15)
      ..lineTo(c.dx + r * 0.22, c.dy + r * 0.15)
      ..lineTo(c.dx, c.dy + r * 0.55)
      ..close();
    canvas.drawPath(hocico, blanco);
    // Nariz
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.42), r * 0.07, Paint()..color = Colors.black87);
    _ojos(canvas, c, r, separacion: 0.28, y: -0.05);
  }

  void _dibujarGato(Canvas canvas, Offset c, double r) {
    final blanco = Paint()..color = Colors.white;
    final rosa = Paint()..color = const Color(0xFFFFC1D9);

    _oreja(canvas, c, r, -1, blanco, ancho: 0.38, alto: 0.55);
    _oreja(canvas, c, r, 1, blanco, ancho: 0.38, alto: 0.55);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.05), r * 0.62, blanco);
    // Interior de orejas
    canvas.drawCircle(Offset(c.dx - r * 0.55, c.dy - r * 0.55), r * 0.1, rosa);
    canvas.drawCircle(Offset(c.dx + r * 0.55, c.dy - r * 0.55), r * 0.1, rosa);
    // Nariz triangular
    final nariz = Path()
      ..moveTo(c.dx - r * 0.06, c.dy + r * 0.15)
      ..lineTo(c.dx + r * 0.06, c.dy + r * 0.15)
      ..lineTo(c.dx, c.dy + r * 0.26)
      ..close();
    canvas.drawPath(nariz, rosa);
    _ojos(canvas, c, r, separacion: 0.24, y: -0.05);
    // Bigotes
    final lineaPaint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.4;
    for (final dy in [-0.02, 0.06]) {
      canvas.drawLine(Offset(c.dx - r * 0.75, c.dy + r * (0.18 + dy)), Offset(c.dx - r * 0.35, c.dy + r * (0.15 + dy)), lineaPaint);
      canvas.drawLine(Offset(c.dx + r * 0.75, c.dy + r * (0.18 + dy)), Offset(c.dx + r * 0.35, c.dy + r * (0.15 + dy)), lineaPaint);
    }
  }

  void _dibujarBuho(Canvas canvas, Offset c, double r) {
    final crema = Paint()..color = const Color(0xFFF3E4C8);
    final marronOscuro = Paint()..color = const Color(0xFF6B4A2B);

    canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.5, height: r * 1.6), crema);
    // Ojos grandes
    canvas.drawCircle(Offset(c.dx - r * 0.34, c.dy - r * 0.05), r * 0.34, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(c.dx + r * 0.34, c.dy - r * 0.05), r * 0.34, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(c.dx - r * 0.34, c.dy - r * 0.05), r * 0.15, marronOscuro);
    canvas.drawCircle(Offset(c.dx + r * 0.34, c.dy - r * 0.05), r * 0.15, marronOscuro);
    // Pico
    final pico = Path()
      ..moveTo(c.dx - r * 0.1, c.dy + r * 0.28)
      ..lineTo(c.dx + r * 0.1, c.dy + r * 0.28)
      ..lineTo(c.dx, c.dy + r * 0.48)
      ..close();
    canvas.drawPath(pico, Paint()..color = const Color(0xFFE0A03A));
  }

  void _dibujarPanda(Canvas canvas, Offset c, double r) {
    final blanco = Paint()..color = Colors.white;
    final negro = Paint()..color = Colors.black87;

    canvas.drawCircle(Offset(c.dx - r * 0.65, c.dy - r * 0.55), r * 0.28, negro);
    canvas.drawCircle(Offset(c.dx + r * 0.65, c.dy - r * 0.55), r * 0.28, negro);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.02), r * 0.68, blanco);
    // Parches de ojos
    canvas.save();
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - r * 0.3, c.dy - r * 0.02), width: r * 0.42, height: r * 0.52), negro);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + r * 0.3, c.dy - r * 0.02), width: r * 0.42, height: r * 0.52), negro);
    canvas.restore();
    _ojos(canvas, c, r, separacion: 0.3, y: -0.02, radio: 0.09, color: Colors.white);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.28), r * 0.08, negro);
  }

  void _dibujarConejo(Canvas canvas, Offset c, double r) {
    final blanco = Paint()..color = Colors.white;
    final rosa = Paint()..color = const Color(0xFFFFC1D9);

    // Orejas largas
    for (final dx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + dx * r * 0.32, c.dy - r * 0.95), width: r * 0.32, height: r * 0.75),
        blanco,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + dx * r * 0.32, c.dy - r * 0.95), width: r * 0.14, height: r * 0.5),
        rosa,
      );
    }
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.1), r * 0.62, blanco);
    final nariz = Path()
      ..moveTo(c.dx - r * 0.06, c.dy + r * 0.18)
      ..lineTo(c.dx + r * 0.06, c.dy + r * 0.18)
      ..lineTo(c.dx, c.dy + r * 0.28)
      ..close();
    canvas.drawPath(nariz, rosa);
    _ojos(canvas, c, r, separacion: 0.24, y: 0.0);
  }

  void _dibujarOso(Canvas canvas, Offset c, double r) {
    final marron = Paint()..color = const Color(0xFF8B6238);
    final marronClaro = Paint()..color = const Color(0xFFD9B98C);

    canvas.drawCircle(Offset(c.dx - r * 0.6, c.dy - r * 0.55), r * 0.26, marron);
    canvas.drawCircle(Offset(c.dx + r * 0.6, c.dy - r * 0.55), r * 0.26, marron);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.02), r * 0.68, marron);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.22), width: r * 0.6, height: r * 0.45), marronClaro);
    _ojos(canvas, c, r, separacion: 0.26, y: -0.05);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.22), r * 0.07, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _AnimalPainter oldDelegate) => oldDelegate.tipo != tipo;
}
