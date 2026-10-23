import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ansiedad/medicion/estado_sensor.dart';
import 'package:app_ansiedad/models/lectura_cruda.dart';
import 'package:app_ansiedad/providers/alerta_provider.dart';
import 'package:app_ansiedad/repositories/sensor_repository.dart';

/// Sensor falso: [conectar] entrega un stream que la prueba alimenta, o lanza
/// el error que se le indique.
class SensorFalso implements SensorRepository {
  Object? error;
  StreamController<String>? canal;
  int desconexiones = 0;

  @override
  Future<Stream<String>> conectar() async {
    if (error != null) throw error!;
    canal = StreamController<String>();
    return canal!.stream;
  }

  @override
  void desconectar() => desconexiones++;

  void enviar(String linea) => canal!.add(linea);
}

String v1(int seq) =>
    jsonEncode({'v': 1, 'seq': seq, 'bpm': 72, 'spo2': 98, 'rr': [820], 'dedo': true, 'estable': true});
String viejo() => jsonEncode({'bpm': 72, 'spo2': 98, 'hrv': 40});

/// Deja correr los microtasks (stream → provider).
Future<void> pausa([int ms = 0]) => Future.delayed(Duration(milliseconds: ms));

void main() {
  late SensorFalso sensor;
  late AlertaProvider alerta;

  setUp(() {
    sensor = SensorFalso();
    alerta = AlertaProvider(sensorRepo: sensor, tiempoVerificacion: const Duration(milliseconds: 60));
  });

  tearDown(() => alerta.dispose());

  test('al abrir no hay fuente ni medición', () {
    expect(alerta.fuente, FuenteLecturas.ninguna);
    expect(alerta.puedeMedir, isFalse);
  });

  test('simulación: se puede medir de inmediato', () {
    alerta.elegirSimulacion();
    expect(alerta.fuente, FuenteLecturas.simulacion);
    expect(alerta.modoSimulacion, isTrue);
    expect(alerta.puedeMedir, isTrue);
  });

  test('sensor compatible: buscando → verificando → listo, y sus lecturas salen', () async {
    final estados = <EstadoSensor>[];
    alerta.addListener(() => estados.add(alerta.estadoSensor));
    final lecturas = <LecturaCruda>[];
    alerta.lecturas.listen(lecturas.add);

    await alerta.elegirSensor();
    expect(alerta.estadoSensor, EstadoSensor.verificando);
    expect(alerta.puedeMedir, isFalse); // aún no se sabe si el firmware es compatible

    sensor.enviar(v1(1));
    await pausa();
    expect(alerta.estadoSensor, EstadoSensor.listo);
    expect(alerta.puedeMedir, isTrue);
    expect(alerta.modoSimulacion, isFalse); // la medición se guarda con origen "sensor"
    expect(lecturas.single.rr, [820]);
    expect(estados, containsAllInOrder([EstadoSensor.buscando, EstadoSensor.verificando, EstadoSensor.listo]));
  });

  test('firmware viejo: no compatible, no se ofrece la medición ni salen lecturas', () async {
    final lecturas = <LecturaCruda>[];
    alerta.lecturas.listen(lecturas.add);
    await alerta.elegirSensor();
    for (var i = 0; i < 3; i++) {
      sensor.enviar(viejo());
    }
    await pausa();
    expect(alerta.estadoSensor, EstadoSensor.noCompatible);
    expect(alerta.puedeMedir, isFalse);
    expect(lecturas, isEmpty);
  });

  test('si no llega nada: "no llegan datos" tras el tiempo límite', () async {
    await alerta.elegirSensor();
    await pausa(120);
    expect(alerta.estadoSensor, EstadoSensor.sinDatos);
    expect(alerta.puedeMedir, isFalse);
  });

  test('si los datos llegan después del tiempo límite, se recupera', () async {
    await alerta.elegirSensor();
    await pausa(120);
    sensor.enviar(v1(1));
    await pausa();
    expect(alerta.estadoSensor, EstadoSensor.listo);
  });

  test('sin dispositivo vinculado y sin permisos', () async {
    sensor.error = SensorException(ErrorSensor.noVinculado, '');
    await alerta.elegirSensor();
    expect(alerta.estadoSensor, EstadoSensor.noVinculado);

    sensor.error = SensorException(ErrorSensor.permisos, '');
    await alerta.elegirSensor(); // "Reintentar"
    expect(alerta.estadoSensor, EstadoSensor.sinPermisos);
    expect(alerta.puedeMedir, isFalse);
  });

  test('un error al abrir la conexión (sensor apagado) queda como error', () async {
    sensor.error = TimeoutException('sin respuesta');
    await alerta.elegirSensor();
    expect(alerta.estadoSensor, EstadoSensor.error);
  });

  test('si la conexión se cae: perdido, y "Reintentar" vuelve a conectar', () async {
    await alerta.elegirSensor();
    sensor.enviar(v1(1));
    await pausa();
    await sensor.canal!.close();
    await pausa();
    expect(alerta.estadoSensor, EstadoSensor.perdido);
    expect(alerta.puedeMedir, isFalse);

    await alerta.elegirSensor();
    sensor.enviar(v1(1));
    await pausa();
    expect(alerta.estadoSensor, EstadoSensor.listo);
  });

  test('cambiar a simulación cierra el sensor sin marcarlo como perdido', () async {
    await alerta.elegirSensor();
    sensor.enviar(v1(1));
    await pausa();
    final antes = sensor.desconexiones;
    alerta.elegirSimulacion();
    expect(sensor.desconexiones, greaterThan(antes));
    expect(alerta.fuente, FuenteLecturas.simulacion);
    expect(alerta.estadoSensor, EstadoSensor.desconectado);
    expect(alerta.puedeMedir, isTrue);
  });

  test('mientras busca o verifica no se puede cambiar de fuente', () async {
    final conectando = alerta.elegirSensor();
    expect(alerta.ocupado, isTrue);
    alerta.elegirSimulacion();
    expect(alerta.fuente, FuenteLecturas.sensor);
    await conectando;
  });
}
