import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/lectura_cruda.dart';
import '../repositories/interprete_sensor.dart';
import '../repositories/sensor_repository.dart';
import '../repositories/simulador_sensor.dart';

/// Mensaje de una sola vez para que la UI muestre un SnackBar (permiso
/// denegado, sensor no vinculado). `advertencia` decide el color: naranja si
/// es true, rojo si es false.
class MensajeAlerta {
  final String texto;
  final bool advertencia;
  MensajeAlerta(this.texto, {this.advertencia = false});
}

/// Fuente de lecturas de la app: el sensor por Bluetooth o la simulación.
///
/// Desde M1c ya no hay vista en vivo (el Monitor se reemplazó por Inicio): este
/// provider solo conecta la fuente y publica cada lectura en [lecturas], que
/// es lo que escucha la sesión de medición (MedicionProvider). No calcula
/// estados ni sube datos.
class AlertaProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;

  AlertaProvider({SensorRepository? sensorRepo}) : _sensorRepo = sensorRepo ?? SensorRepository();

  bool _sensorConectado = false;
  bool get sensorConectado => _sensorConectado;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _modoSimulacion = false;
  bool get modoSimulacion => _modoSimulacion;

  StreamSubscription<String>? _sensorSub;
  Timer? _simTimer;
  final SimuladorSensor _simulador = SimuladorSensor();

  /// Todas las lecturas que llegan (sensor o simulación), incluidas las de
  /// mala señal. La sesión de medición (MedicionProvider) las escucha aquí.
  final StreamController<LecturaCruda> _lecturas = StreamController<LecturaCruda>.broadcast();
  Stream<LecturaCruda> get lecturas => _lecturas.stream;

  /// Aplica el contrato del sensor (CONTRATO_SENSOR.md) a cada línea: lectura
  /// estricta, huecos en `seq`, firmware viejo y una lectura por segundo.
  final InterpreteSensor _interprete = InterpreteSensor();

  /// Si el firmware del sensor conectado habla el contrato. La medición con
  /// el sensor solo se ofrece cuando es [EstadoFirmware.compatible] (paso 4).
  EstadoFirmware get firmware => _interprete.firmware;

  bool get forzandoMalaSenal => _simulador.forzarMalaSenal;

  /// Botón de prueba de la simulación. [notificar] en false permite apagarlo
  /// desde un `dispose` sin redibujar a media desmontada.
  void setForzarMalaSenal(bool valor, {bool notificar = true}) {
    _simulador.forzarMalaSenal = valor;
    if (notificar) notifyListeners();
  }

  /// Al empezar una medición en simulación: unos segundos de estabilización.
  void simularColocacionDedo() => _simulador.colocarDedo();

  @override
  void dispose() {
    _simTimer?.cancel();
    _sensorSub?.cancel();
    _sensorRepo.desconectar();
    _lecturas.close();
    super.dispose();
  }

  // --- CONEXIÓN AL SENSOR (sin uso en la UI hasta que el firmware mande RR y
  // calidad de señal; ver M7) ---

  Future<MensajeAlerta?> escanearYConectar() async {
    if (_isScanning) return null;
    if (_modoSimulacion) detenerSimulacion();

    _isScanning = true;
    notifyListeners();

    try {
      final stream = await _sensorRepo.conectar();
      _interprete.reiniciar(); // el firmware se vuelve a verificar en cada conexión
      _sensorConectado = true;
      _isScanning = false;
      notifyListeners();

      _sensorSub = stream.listen(_procesarLineaCruda, onDone: () {
        _sensorConectado = false;
        notifyListeners();
      });
      return null;
    } on SensorException catch (e) {
      _isScanning = false;
      notifyListeners();
      return MensajeAlerta(e.mensaje, advertencia: e.tipo == ErrorSensor.noVinculado);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al conectar sensor', tag: 'alerta', error: e, stackTrace: stackTrace);
      _isScanning = false;
      notifyListeners();
      return null;
    }
  }

  void _procesarLineaCruda(String linea) {
    final antes = _interprete.firmware;
    final lectura = _interprete.procesar(linea);
    if (lectura != null) _lecturas.add(lectura);
    if (_interprete.firmware != antes) {
      if (_interprete.firmware == EstadoFirmware.noCompatible) {
        AppLogger.warning('Firmware del sensor no compatible con el contrato v1', tag: 'alerta');
      }
      notifyListeners();
    }
  }

  // --- MODO SIMULACIÓN (SimuladorSensor: RR latido a latido y mala señal) ---

  void toggleSimulacion() {
    if (_modoSimulacion) {
      detenerSimulacion();
    } else {
      iniciarSimulacion();
    }
  }

  void iniciarSimulacion() {
    // No mezclar simulación con una conexión Bluetooth real activa.
    _sensorSub?.cancel();
    _sensorSub = null;
    _sensorRepo.desconectar();

    _modoSimulacion = true;
    _sensorConectado = true;
    notifyListeners();

    // Una lectura por segundo, como la espera la sesión de medición.
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lecturas.add(_simulador.siguiente());
    });
  }

  void detenerSimulacion() {
    _simTimer?.cancel();
    _simTimer = null;
    _modoSimulacion = false;
    _sensorConectado = false;
    notifyListeners();
  }
}
