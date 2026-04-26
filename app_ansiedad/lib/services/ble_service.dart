import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // UUIDs exactos de tu ESP32
  final String targetDeviceName = "ESP32_Ansiedad_Sensor";
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  StreamSubscription<List<int>>? notifySubscription;

  // 1. Iniciar Escaneo
  Future<void> scanAndConnect() async {
    print("BLE: Iniciando escaneo...");

    // Verifica que el Bluetooth del celular esté encendido
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      print("BLE: ¡Enciende el Bluetooth de tu celular!");
      return;
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    // 2. Escuchar los resultados del escaneo
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == targetDeviceName) {
          print("BLE: ¡ESP32 Encontrado! Conectando...");
          FlutterBluePlus.stopScan(); // Detener escaneo para ahorrar batería
          targetDevice = r.device;
          await connectToDevice();
          break;
        }
      }
    });
  }

  // 3. Conectar y buscar los servicios
  Future<void> connectToDevice() async {
    if (targetDevice == null) return;

    try {
      await targetDevice!.connect(license: License.free);
      print("BLE: ¡Conexión exitosa al ESP32!");

      List<BluetoothService> services = await targetDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == characteristicUuid) {
              targetCharacteristic = characteristic;
              print("BLE: ¡Característica lista para leer datos!");
              await subscribeToNotifications();
            }
          }
        }
      }
    } catch (e) {
      print("BLE: Error al conectar -> $e");
    }
  }

  // 4. Suscribirse a los datos en tiempo real
  Future<void> subscribeToNotifications() async {
    if (targetCharacteristic == null) return;

    await targetCharacteristic!.setNotifyValue(true);
    notifySubscription = targetCharacteristic!.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        // El ESP32 manda bytes, los convertimos a texto
        String data = utf8.decode(value);
        print("❤️ DATO RECIBIDO: $data"); // Aquí veremos tu "BPM,RR"
      }
    });
  }

  // Desconectar
  void disconnect() {
    notifySubscription?.cancel();
    targetDevice?.disconnect();
    print("BLE: Desconectado");
  }
}