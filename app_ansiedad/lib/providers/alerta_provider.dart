import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../app_config.dart';
import '../logger.dart';
import '../models/lectura_cruda.dart';
import '../repositories/lectura_repository.dart';
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

enum ResultadoSync { sinDatos, exito, error }

class ResultadoSincronizacion {
  final ResultadoSync resultado;
  final String? mensajeError;
  ResultadoSincronizacion(this.resultado, {this.mensajeError});
}

/// Maneja TODO el estado y la lógica de la pantalla de Alerta (Monitor).
///
/// La UI ya no toca Bluetooth, red, ni calcula el semáforo de ansiedad: le
/// pide a este provider y escucha sus cambios con notifyListeners(), igual
/// que HistorialProvider y PerfilProvider.
class AlertaProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;
  final LecturaRepository _lecturaRepo;
  final String pacienteId;

  AlertaProvider({
    required this.pacienteId,
    SensorRepository? sensorRepo,
    LecturaRepository? lecturaRepo,
  })  : _sensorRepo = sensorRepo ?? SensorRepository(),
        _lecturaRepo = lecturaRepo ?? LecturaRepository();

  String _lastSyncTime = "Sin conexión";
  String get lastSyncTime => _lastSyncTime;

  bool _sensorConectado = false;
  bool get sensorConectado => _sensorConectado;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _modoSimulacion = false;
  bool get modoSimulacion => _modoSimulacion;

  int _bpmActual = 0;
  int get bpmActual => _bpmActual;

  int _spo2Actual = 0;
  int get spo2Actual => _spo2Actual;

  int _hrvActual = 0;
  int get hrvActual => _hrvActual;

  // Null hasta que llega la primera lectura (antes de eso la UI muestra
  // "Esperando sensor..." en vez de un estado de ansiedad real).
  EstadoAnsiedad? _estado;
  bool get tieneLectura => _estado != null;
  String get estadoAnsiedadTexto => _estado?.textoDB ?? "Esperando sensor...";
  double get ansiedadScore => _estado?.scoreRepresentativo ?? 0.0;

  final List<int> _tendenciaBpm = [];
  List<int> get tendenciaBpm => _tendenciaBpm;

  final List<int> _bufferBpm = [];
  final List<int> _bufferSpo2 = [];
  final List<int> _bufferHrv = [];
  bool get tieneDatosPendientes => _bufferBpm.isNotEmpty;

  StreamSubscription<String>? _sensorSub;
  Timer? _simTimer;
  final SimuladorSensor _simulador = SimuladorSensor();

  /// Todas las lecturas que llegan (sensor o simulación), incluidas las de
  /// mala señal. La sesión de medición (MedicionProvider) las escucha aquí.
  final StreamController<LecturaCruda> _lecturas = StreamController<LecturaCruda>.broadcast();
  Stream<LecturaCruda> get lecturas => _lecturas.stream;

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

  // --- CONEXIÓN AL SENSOR ---

  Future<MensajeAlerta?> escanearYConectar() async {
    if (_isScanning) return null;
    if (_modoSimulacion) detenerSimulacion();

    _isScanning = true;
    _lastSyncTime = "Buscando vinculado...";
    notifyListeners();

    try {
      final stream = await _sensorRepo.conectar();
      _sensorConectado = true;
      _isScanning = false;
      _lastSyncTime = "En vivo (Serial)";
      notifyListeners();

      _sensorSub = stream.listen(_procesarLineaCruda, onDone: () {
        _sensorConectado = false;
        _lastSyncTime = "Desconectado";
        notifyListeners();
      });
      return null;
    } on SensorException catch (e) {
      _isScanning = false;
      _lastSyncTime = e.tipo == ErrorSensor.permisos ? "Sin permisos" : "No vinculado";
      notifyListeners();
      return MensajeAlerta(e.mensaje, advertencia: e.tipo == ErrorSensor.noVinculado);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al conectar sensor', tag: 'alerta', error: e, stackTrace: stackTrace);
      _isScanning = false;
      _lastSyncTime = "Error de enlace";
      notifyListeners();
      return null;
    }
  }

  void _procesarLineaCruda(String linea) {
    try {
      final datos = jsonDecode(linea) as Map<String, dynamic>;
      final anterior = LecturaCruda(bpm: _bpmActual, spo2: _spo2Actual, hrv: _hrvActual);
      _procesarLectura(LecturaCruda.fromJson(datos, anterior: anterior));
    } catch (e) {
      // Línea corrupta del sensor: se ignora y se espera la siguiente. Nivel
      // debug (no error): es ruido esperado del serial, no una falla real.
      AppLogger.debug('Línea de sensor descartada: $e', tag: 'alerta');
    }
  }

  void _procesarLectura(LecturaCruda lectura) {
    _lecturas.add(lectura);
    // Sin dedo no hay lectura que mostrar: la vista en vivo conserva la última.
    if (!lectura.dedo) return;

    _bpmActual = lectura.bpm;
    _spo2Actual = lectura.spo2;
    _hrvActual = lectura.hrv;

    _tendenciaBpm.add(_bpmActual);
    if (_tendenciaBpm.length > 20) _tendenciaBpm.removeAt(0);

    _bufferBpm.add(_bpmActual);
    _bufferSpo2.add(_spo2Actual);
    _bufferHrv.add(_hrvActual);

    // Semáforo de ansiedad: un solo lugar decide el nivel; texto, color y
    // score se derivan del enum central en app_config.dart.
    if (_bpmActual > 95 || _hrvActual < 25) {
      _estado = EstadoAnsiedad.alta;
    } else if (_bpmActual > 85) {
      _estado = EstadoAnsiedad.moderada;
    } else {
      _estado = EstadoAnsiedad.baja;
    }

    notifyListeners();
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
    _lastSyncTime = "En vivo (Simulado)";
    notifyListeners();

    // Una lectura por segundo, como la espera la sesión de medición.
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _procesarLectura(_simulador.siguiente());
    });
  }

  void detenerSimulacion() {
    _simTimer?.cancel();
    _simTimer = null;
    _modoSimulacion = false;
    _sensorConectado = false;
    _lastSyncTime = "Simulación detenida";
    notifyListeners();
  }

  // --- SINCRONIZACIÓN CON BACKEND (REMITIR PROMEDIOS) ---

  Future<ResultadoSincronizacion> enviarResumen() async {
    if (_bufferBpm.isEmpty) {
      return ResultadoSincronizacion(ResultadoSync.sinDatos);
    }

    final estadoActual = _estado ?? EstadoAnsiedad.baja;

    try {
      await _lecturaRepo.enviarResumen(
        pacienteId: pacienteId,
        bpm: _promedio(_bufferBpm),
        spo2: _promedio(_bufferSpo2),
        hrv: _promedio(_bufferHrv),
        scoreAnsiedad: estadoActual.scoreRepresentativo,
        estadoAnsiedad: estadoActual.textoDB,
      );
      _bufferBpm.clear();
      _bufferSpo2.clear();
      _bufferHrv.clear();
      return ResultadoSincronizacion(ResultadoSync.exito);
    } on RepositoryException catch (e) {
      // No limpiamos el buffer: si falla el guardado, no se pierden lecturas.
      return ResultadoSincronizacion(ResultadoSync.error, mensajeError: e.mensaje);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al sincronizar resumen', tag: 'alerta', error: e, stackTrace: stackTrace);
      return ResultadoSincronizacion(ResultadoSync.error, mensajeError: "Ocurrió un error inesperado.");
    }
  }

  int _promedio(List<int> valores) => (valores.reduce((a, b) => a + b) / valores.length).round();
}
