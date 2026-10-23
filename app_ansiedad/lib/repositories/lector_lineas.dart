import 'dart:convert';

/// Arma líneas completas a partir de los bytes que van llegando por el
/// Bluetooth del sensor (Fase M7a). Lógica pura, sin Bluetooth: se prueba con
/// `flutter test` (test/lector_lineas_test.dart).
///
/// El serial no respeta los límites de los paquetes del ESP32: un paquete de
/// bytes puede traer varias líneas, media línea o el final de una y el
/// principio de otra. [agregar] devuelve TODAS las líneas que se completaron,
/// en orden, y guarda lo que quede a medias para el siguiente paquete.
///
/// - Separa por `\n`; un `\r` al final (`\r\n`) y los espacios se quitan.
///   Las líneas vacías se ignoran.
/// - Decodifica UTF-8 con tolerancia: un byte basura se vuelve `�` y la línea
///   llega igual (luego el JSON la descartará), en vez de tronar.
/// - Si se juntan más de [topeBytes] sin `\n` (basura, o una línea que nunca
///   termina), se tira lo acumulado y también el resto hasta el próximo `\n`,
///   para no entregar después la cola de esa basura como si fuera una línea.
class LectorLineas {
  /// Tope del buffer. Una línea del contrato mide menos de 200 bytes.
  static const int topeBytes = 1024;

  final List<int> _pendiente = [];
  bool _descartando = false;

  /// Agrega los bytes de un paquete y devuelve las líneas que se completaron.
  List<String> agregar(List<int> bytes) {
    final lineas = <String>[];
    for (final b in bytes) {
      if (b == 0x0A) {
        if (_descartando) {
          _descartando = false;
        } else {
          final linea = utf8.decode(_pendiente, allowMalformed: true).trim();
          if (linea.isNotEmpty) lineas.add(linea);
        }
        _pendiente.clear();
      } else if (!_descartando) {
        _pendiente.add(b);
        if (_pendiente.length > topeBytes) {
          _pendiente.clear();
          _descartando = true;
        }
      }
    }
    return lineas;
  }

  /// Olvida lo que quedó a medias (al desconectar o reconectar el sensor).
  void reiniciar() {
    _pendiente.clear();
    _descartando = false;
  }
}
