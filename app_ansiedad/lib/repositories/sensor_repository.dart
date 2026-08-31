import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

/// Nombre del dispositivo Bluetooth vinculado que expone el sensor ESP32.
const _nombreDispositivoSensor = "TT_SENSOR_CLASICO";

enum ErrorSensor { permisos, noVinculado }

/// Excepción de la conexión al sensor, con mensaje ya listo para el usuario.
class SensorException implements Exception {
  final ErrorSensor tipo;
  final String mensaje;
  SensorException(this.tipo, this.mensaje);
  @override
  String toString() => mensaje;
}

/// Encapsula el acceso a Bluetooth Serial del sensor biométrico (ESP32).
///
/// La UI/provider no habla directo con `flutter_bluetooth_serial`: le pide a
/// este repositorio que conecte y escucha el stream de líneas JSON crudas
/// que va soltando el sensor.
class SensorRepository {
  BluetoothConnection? _connection;
  String _bufferDatos = "";

  Future<bool> _solicitarPermisos() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses[Permission.bluetoothConnect]?.isGranted ?? false;
  }

  /// Busca el dispositivo vinculado y abre la conexión serial. Devuelve un
  /// stream con cada línea JSON cruda que manda el sensor; el stream se
  /// cierra solo cuando el dispositivo se desconecta.
  Future<Stream<String>> conectar() async {
    final permisosOk = await _solicitarPermisos();
    if (!permisosOk) {
      throw SensorException(ErrorSensor.permisos, "Se requieren permisos de Bluetooth para el sensor.");
    }

    final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? esp32;
    for (final d in bondedDevices) {
      if (d.name != null && d.name!.contains(_nombreDispositivoSensor)) {
        esp32 = d;
        break;
      }
    }

    if (esp32 == null) {
      throw SensorException(ErrorSensor.noVinculado, 'Vincula "$_nombreDispositivoSensor" en los ajustes del celular.');
    }

    _connection = await BluetoothConnection.toAddress(esp32.address);

    final controller = StreamController<String>();
    _connection!.input!.listen((Uint8List data) {
      _bufferDatos += ascii.decode(data);
      if (_bufferDatos.contains('\n')) {
        final lineas = _bufferDatos.split('\n');
        final linea = lineas[0].trim();
        _bufferDatos = lineas.length > 1 ? lineas[1] : "";
        if (linea.isNotEmpty) controller.add(linea);
      }
    }).onDone(() {
      controller.close();
    });

    return controller.stream;
  }

  void desconectar() {
    _connection?.dispose();
    _connection = null;
    _bufferDatos = "";
  }
}
