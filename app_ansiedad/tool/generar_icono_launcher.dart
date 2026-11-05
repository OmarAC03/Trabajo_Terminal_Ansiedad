// Primer plano del icono adaptativo de la app (Bloque 3, D6), a partir de la
// mascota `avatar_feliz` (3x, 288 px). Luego flutter_launcher_icons genera
// los mipmap con la configuración de pubspec.yaml:
//
//   dart run tool/generar_icono_launcher.dart
//   dart run flutter_launcher_icons
//
// El avatar trae un círculo claro con una orilla gris: se quita todo lo que
// se alcanza desde las esquinas sin cruzar a la mascota (relleno por
// inundación), y queda solo el personaje. Android recorta el icono
// adaptativo (108 dp) a la zona segura del centro (66 dp ≈ 264 px de 432):
// la mascota se deja en 240 px de ancho para que ningún launcher la corte.
import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

const anchoMascota = 240;
const lado = 432;

// Píxel de la mascota: azul del cuerpo o los trazos oscuros de la cara.
bool _mascota(img.Pixel p) {
  if (p.a < 32) return false;
  final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  return (p.b - p.r) > 60 || luma < 90;
}

void main() {
  final a = img.decodePng(File('assets/mascota/3.0x/avatar_feliz.png').readAsBytesSync())!;
  final w = a.width, h = a.height;
  final fondo = List<bool>.filled(w * h, false);
  final cola = Queue<int>();
  for (final i in [0, w - 1, (h - 1) * w, h * w - 1]) {
    fondo[i] = true;
    cola.add(i);
  }
  while (cola.isNotEmpty) {
    final j = cola.removeFirst();
    final x = j % w, y = j ~/ w;
    for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final k = ny * w + nx;
      if (!fondo[k] && !_mascota(a.getPixel(nx, ny))) {
        fondo[k] = true;
        cola.add(k);
      }
    }
  }

  var x0 = w, y0 = h, x1 = 0, y1 = 0;
  for (var i = 0; i < w * h; i++) {
    if (fondo[i]) {
      a.setPixelRgba(i % w, i ~/ w, 0, 0, 0, 0);
      continue;
    }
    final x = i % w, y = i ~/ w;
    if (x < x0) x0 = x;
    if (y < y0) y0 = y;
    if (x > x1) x1 = x;
    if (y > y1) y1 = y;
  }

  final recorte = img.copyCrop(a, x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1);
  final alto = (recorte.height * anchoMascota / recorte.width).round();
  final reducida = img.copyResize(recorte, width: anchoMascota, height: alto, interpolation: img.Interpolation.average);
  final lienzo = img.Image(width: lado, height: lado, numChannels: 4);
  img.compositeImage(lienzo, reducida, dstX: (lado - anchoMascota) ~/ 2, dstY: (lado - alto) ~/ 2);
  final destino = File('tool/icono/icono_primer_plano.png')..parent.createSync(recursive: true);
  destino.writeAsBytesSync(img.encodePng(lienzo));
  stdout.writeln('${destino.path} ($lado px, mascota $anchoMascota x $alto)');
}
