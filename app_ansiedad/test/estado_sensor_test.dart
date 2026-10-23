import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/medicion/estado_sensor.dart';

void main() {
  test('cada estado tiene su texto, y ninguno lleva etiquetas ni valores', () {
    final prohibidas = RegExp(r'normal|elevad|alto|ansiedad|lpm|bpm|ms\b|%|\d', caseSensitive: false);
    for (final e in EstadoSensor.values) {
      final texto = textoEstadoSensor(e);
      expect(texto, isNotEmpty, reason: '$e');
      // El nombre del dispositivo trae letras y guiones bajos, sin números.
      expect(texto.replaceAll(nombreSensor, ''), isNot(contains(prohibidas)), reason: '$e: $texto');
    }
  });

  test('"no vinculado" dice qué dispositivo vincular', () {
    expect(textoEstadoSensor(EstadoSensor.noVinculado), contains('Vincula $nombreSensor'));
  });

  test('ocupado solo buscando o verificando; reintentar solo en los problemas', () {
    expect(EstadoSensor.values.where(sensorOcupado).toSet(), {EstadoSensor.buscando, EstadoSensor.verificando});
    expect(EstadoSensor.values.where(sensorReintentable).toSet(), {
      EstadoSensor.noVinculado,
      EstadoSensor.sinPermisos,
      EstadoSensor.noCompatible,
      EstadoSensor.sinDatos,
      EstadoSensor.perdido,
      EstadoSensor.error,
    });
  });
}
