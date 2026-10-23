import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/repositories/lector_lineas.dart';

List<int> b(String s) => utf8.encode(s);

const l1 = '{"v":1,"seq":1,"bpm":72,"spo2":97,"rr":[812],"dedo":true,"estable":true}';
const l2 = '{"v":1,"seq":2,"bpm":73,"spo2":97,"rr":[798,805],"dedo":true,"estable":true}';
const l3 = '{"v":1,"seq":3,"bpm":0,"spo2":0,"rr":[],"dedo":false,"estable":false}';

void main() {
  test('una línea completa en un paquete', () {
    expect(LectorLineas().agregar(b('$l1\n')), [l1]);
  });

  test('varias líneas en un mismo paquete: llegan todas, en orden', () {
    // El lector viejo solo emitía la primera y perdía de la tercera en adelante.
    expect(LectorLineas().agregar(b('$l1\n$l2\n$l3\n')), [l1, l2, l3]);
  });

  test('una línea partida en varios paquetes se arma al llegar el \\n', () {
    final lector = LectorLineas();
    expect(lector.agregar(b(l1.substring(0, 10))), isEmpty);
    expect(lector.agregar(b(l1.substring(10, 40))), isEmpty);
    expect(lector.agregar(b('${l1.substring(40)}\n')), [l1]);
  });

  test('final de una línea y principio de otra en el mismo paquete', () {
    final lector = LectorLineas();
    expect(lector.agregar(b('$l1\n${l2.substring(0, 20)}')), [l1]);
    expect(lector.agregar(b('${l2.substring(20)}\n$l3\n')), [l2, l3]);
  });

  test('paquetes de un byte a la vez', () {
    final lector = LectorLineas();
    final salida = <String>[];
    for (final byte in b('$l1\n$l2\n')) {
      salida.addAll(lector.agregar([byte]));
    }
    expect(salida, [l1, l2]);
  });

  test('saltos de línea \\r\\n: el \\r no queda en la línea', () {
    expect(LectorLineas().agregar(b('$l1\r\n$l2\r\n')), [l1, l2]);
  });

  test('\\r\\n partido entre dos paquetes', () {
    final lector = LectorLineas();
    expect(lector.agregar(b('$l1\r')), isEmpty);
    expect(lector.agregar(b('\n')), [l1]);
  });

  test('líneas vacías y solo espacios se ignoran', () {
    expect(LectorLineas().agregar(b('\n\r\n  \n$l1\n\n')), [l1]);
  });

  test('bytes que no son ASCII ni UTF-8 válido no truenan', () {
    final lector = LectorLineas();
    final lineas = lector.agregar([0xFF, 0xFE, 0x80, ...b('abc'), 0x0A, ...b('$l1\n')]);
    expect(lineas, hasLength(2));
    expect(lineas[0], contains('abc'));
    expect(lineas[1], l1);
  });

  test('un carácter UTF-8 de varios bytes partido entre paquetes se arma bien', () {
    final lector = LectorLineas();
    final bytes = b('señal\n');
    final corte = bytes.indexOf(0xC3) + 1; // a la mitad de la "ñ"
    expect(lector.agregar(bytes.sublist(0, corte)), isEmpty);
    expect(lector.agregar(bytes.sublist(corte)), ['señal']);
  });

  test('basura sin \\n por encima del tope se descarta hasta el siguiente \\n', () {
    final lector = LectorLineas();
    final basura = List<int>.filled(LectorLineas.topeBytes + 500, 0x41); // "AAAA…"
    expect(lector.agregar(basura), isEmpty);
    // La cola de la basura tampoco se entrega como línea; la siguiente sí.
    expect(lector.agregar(b('AAAA\n$l1\n')), [l1]);
  });

  test('una línea justo en el tope todavía se acepta', () {
    final larga = 'x' * LectorLineas.topeBytes;
    expect(LectorLineas().agregar(b('$larga\n')), [larga]);
  });

  test('reiniciar olvida lo que quedó a medias', () {
    final lector = LectorLineas();
    lector.agregar(b(l1.substring(0, 30)));
    lector.reiniciar();
    expect(lector.agregar(b('$l2\n')), [l2]);
  });
}
