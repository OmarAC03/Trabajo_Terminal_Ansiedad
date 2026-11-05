// Genera el icono pequeño de las notificaciones (barra de estado) a partir de
// la mascota (Bloque 3). Android lo pinta solo con su canal alfa, así que
// debe ser una silueta BLANCA sobre transparente; si no, se ve un cuadro gris.
//
//   dart run tool/generar_icono_notificacion.dart
//
// Toma el cuerpo de la mascota (la región conexa más grande de píxeles no
// oscuros): quedan fuera las líneas de movimiento, y los ojos y la boca
// (oscuros) quedan como huecos. Escribe android/app/src/main/res/
// drawable-*/ic_notificacion.png. El paquete `image` (MIT) llega con
// flutter_launcher_icons (solo de desarrollo).
import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

const fuente = 'assets/mascota/3.0x/mascota_reposo.png';
// Tamaño del icono por densidad (24 dp) y del dibujo dentro (22 dp).
const densidades = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96};

bool _cuerpo(img.Pixel p) {
  if (p.a < 128) return false;
  final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  return luma > 70; // ojos y boca (azul marino) quedan fuera
}

void main() {
  final original = img.decodePng(File(fuente).readAsBytesSync())!;
  final w = original.width, h = original.height;

  // Región conexa más grande de píxeles de "cuerpo".
  final etiqueta = List<int>.filled(w * h, -1);
  var mejor = -1, mejorTam = 0, actual = 0;
  for (var i = 0; i < w * h; i++) {
    if (etiqueta[i] != -1 || !_cuerpo(original.getPixel(i % w, i ~/ w))) continue;
    var tam = 0;
    final cola = Queue<int>()..add(i);
    etiqueta[i] = actual;
    while (cola.isNotEmpty) {
      final j = cola.removeFirst();
      tam++;
      final x = j % w, y = j ~/ w;
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final k = ny * w + nx;
        if (etiqueta[k] == -1 && _cuerpo(original.getPixel(nx, ny))) {
          etiqueta[k] = actual;
          cola.add(k);
        }
      }
    }
    if (tam > mejorTam) {
      mejorTam = tam;
      mejor = actual;
    }
    actual++;
  }

  // Silueta blanca recortada a su caja.
  var x0 = w, y0 = h, x1 = 0, y1 = 0;
  for (var i = 0; i < w * h; i++) {
    if (etiqueta[i] != mejor) continue;
    final x = i % w, y = i ~/ w;
    if (x < x0) x0 = x;
    if (y < y0) y0 = y;
    if (x > x1) x1 = x;
    if (y > y1) y1 = y;
  }
  final lado = (x1 - x0 > y1 - y0 ? x1 - x0 : y1 - y0) + 1;
  final silueta = img.Image(width: lado, height: lado, numChannels: 4);
  final ox = (lado - (x1 - x0 + 1)) ~/ 2, oy = (lado - (y1 - y0 + 1)) ~/ 2;
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      if (etiqueta[y * w + x] == mejor) silueta.setPixelRgba(x - x0 + ox, y - y0 + oy, 255, 255, 255, 255);
    }
  }

  for (final MapEntry(key: carpeta, value: tam) in densidades.entries) {
    final dibujo = (tam * 22 / 24).round();
    final escalada = img.copyResize(silueta, width: dibujo, height: dibujo, interpolation: img.Interpolation.average);
    final lienzo = img.Image(width: tam, height: tam, numChannels: 4);
    img.compositeImage(lienzo, escalada, dstX: (tam - dibujo) ~/ 2, dstY: (tam - dibujo) ~/ 2);
    final destino = File('android/app/src/main/res/drawable-$carpeta/ic_notificacion.png');
    destino.parent.createSync(recursive: true);
    destino.writeAsBytesSync(img.encodePng(lienzo));
    stdout.writeln('${destino.path} ($tam px)');
  }
}
