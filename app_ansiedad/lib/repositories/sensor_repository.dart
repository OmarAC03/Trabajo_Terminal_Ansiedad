import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'lector_lineas.dart';

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
/// La UI/provider no habla directo con `flutter_classic_bluetooth` (Bluetooth
/// clásico, SPP): le pide a este repositorio que conecte y escucha el stream
/// de líneas JSON crudas que va soltando el sensor.
class SensorRepository {
  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  BtcConnection? _connection;
  final LectorLineas _lector = LectorLineas();

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

    final bondedDevices = await _bluetooth.getPairedDevices();
    BtcDevice? esp32;
    for (final d in bondedDevices) {
      if (d.name != null && d.name!.contains(_nombreDispositivoSensor)) {
        esp32 = d;
        break;
      }
    }

    if (esp32 == null) {
      throw SensorException(ErrorSensor.noVinculado, 'Vincula "$_nombreDispositivoSensor" en los ajustes del celular.');
    }

    // Perfil SPP (el UUID por defecto del plugin), igual que SerialBT del ESP32.
    final connection = await _bluetooth.connect(address: esp32.address);
    _connection = connection;

    _lector.reiniciar();
    final controller = StreamController<String>();
    connection.input.listen((Uint8List data) {
      // Un paquete puede traer varias líneas o media: salen todas, en orden.
      for (final linea in _lector.agregar(data)) {
        controller.add(linea);
      }
    }).onDone(() {
      controller.close();
    });

    return controller.stream;
  }

  void desconectar() {
    // close() es asíncrono; no se espera (la firma sigue siendo síncrona) y
    // un error al cerrar una conexión que ya se cayó no importa.
    _connection?.close().catchError((_) {});
    _connection = null;
    _lector.reiniciar();
  }
}
