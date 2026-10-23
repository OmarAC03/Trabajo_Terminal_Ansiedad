import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../medicion/estado_sensor.dart';
import '../models/lectura_cruda.dart';
import '../repositories/interprete_sensor.dart';
import '../repositories/sensor_repository.dart';
import '../repositories/simulador_sensor.dart';

/// Fuente de lecturas de la app: el sensor por Bluetooth o la simulación.
///
/// Desde M1c ya no hay vista en vivo (el Monitor se reemplazó por Inicio): este
/// provider solo conecta la fuente y publica cada lectura en [lecturas], que
/// es lo que escucha la sesión de medición (MedicionProvider). No calcula
/// estados ni sube datos.
///
/// Desde M7a (paso 4) el paciente elige la fuente en Inicio ([elegirSimulacion]
/// / [elegirSensor]) y [estadoSensor] dice cómo va la conexión; la medición
/// solo se ofrece cuando [puedeMedir].
class AlertaProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;

  /// Si el sensor se conecta pero no llega ningún paquete en este tiempo, el
  /// estado pasa a [EstadoSensor.sinDatos] en vez de quedarse "verificando".
  final Duration tiempoVerificacion;

  AlertaProvider({SensorRepository? sensorRepo, this.tiempoVerificacion = const Duration(seconds: 8)})
      : _sensorRepo = sensorRepo ?? SensorRepository();

  FuenteLecturas _fuente = FuenteLecturas.ninguna;
  FuenteLecturas get fuente => _fuente;
  bool get modoSimulacion => _fuente == FuenteLecturas.simulacion;

  EstadoSensor _estadoSensor = EstadoSensor.desconectado;
  EstadoSensor get estadoSensor => _estadoSensor;

  /// Mientras se busca o se verifica el sensor no se cambia de fuente.
  bool get ocupado => _fuente == FuenteLecturas.sensor && sensorOcupado(_estadoSensor);

  /// "Iniciar medición": con la simulación, o con el sensor conectado y con
  /// un firmware que habla el contrato.
  bool get puedeMedir =>
      _fuente == FuenteLecturas.simulacion || (_fuente == FuenteLecturas.sensor && _estadoSensor == EstadoSensor.listo);

  StreamSubscription<String>? _sensorSub;
  Timer? _verificacionTimer;
  Timer? _simTimer;
  final SimuladorSensor _simulador = SimuladorSensor();

  /// Evita que una conexión vieja (por ejemplo, de un "Reintentar" anterior)
  /// pise el estado de la actual.
  int _intento = 0;

  /// Todas las lecturas que llegan (sensor o simulación), incluidas las de
  /// mala señal. La sesión de medición (MedicionProvider) las escucha aquí.
  final StreamController<LecturaCruda> _lecturas = StreamController<LecturaCruda>.broadcast();
  Stream<LecturaCruda> get lecturas => _lecturas.stream;

  /// Aplica el contrato del sensor (CONTRATO_SENSOR.md) a cada línea: lectura
  /// estricta, huecos en `seq`, firmware viejo y una lectura por segundo.
  final InterpreteSensor _interprete = InterpreteSensor();

  /// Si el firmware del sensor conectado habla el contrato.
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

  bool _desechado = false;

  @override
  void dispose() {
    _desechado = true;
    _simTimer?.cancel();
    _cerrarSensor();
    _lecturas.close();
    super.dispose();
  }

  void _cambiarEstado(EstadoSensor estado) {
    _estadoSensor = estado;
    if (!_desechado) notifyListeners();
  }

  // --- ELEGIR FUENTE ---

  void elegirSimulacion() {
    if (ocupado || _fuente == FuenteLecturas.simulacion) return;
    // No mezclar simulación con una conexión Bluetooth real activa.
    _cerrarSensor();
    _estadoSensor = EstadoSensor.desconectado;
    _fuente = FuenteLecturas.simulacion;
    _simTimer?.cancel();
    // Una lectura por segundo, como la espera la sesión de medición.
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _lecturas.add(_simulador.siguiente());
    });
    notifyListeners();
  }

  /// Elige el sensor y lo conecta. También es el "Reintentar".
  Future<void> elegirSensor() async {
    if (ocupado) return;
    if (_fuente == FuenteLecturas.sensor && _estadoSensor == EstadoSensor.listo) return;
    _simTimer?.cancel();
    _simTimer = null;
    _cerrarSensor();
    _fuente = FuenteLecturas.sensor;
    final intento = ++_intento;
    _cambiarEstado(EstadoSensor.buscando);

    try {
      final stream = await _sensorRepo.conectar();
      if (intento != _intento || _desechado) return; // se eligió otra cosa mientras conectaba
      _interprete.reiniciar(); // el firmware se vuelve a verificar en cada conexión
      _sensorSub = stream.listen(_procesarLineaCruda, onDone: () {
        if (intento != _intento) return;
        _cerrarSensor();
        _cambiarEstado(EstadoSensor.perdido);
      });
      _verificacionTimer = Timer(tiempoVerificacion, () {
        if (intento == _intento && _estadoSensor == EstadoSensor.verificando) {
          AppLogger.warning('El sensor se conectó pero no llegaron paquetes', tag: 'alerta');
          _cambiarEstado(EstadoSensor.sinDatos);
        }
      });
      _cambiarEstado(EstadoSensor.verificando);
    } on SensorException catch (e) {
      if (intento != _intento) return;
      _cambiarEstado(e.tipo == ErrorSensor.permisos ? EstadoSensor.sinPermisos : EstadoSensor.noVinculado);
    } catch (e, stackTrace) {
      if (intento != _intento) return;
      AppLogger.error('Error al conectar el sensor', tag: 'alerta', error: e, stackTrace: stackTrace);
      _cambiarEstado(EstadoSensor.error);
    }
  }

  /// Cierra la conexión con el sensor sin avisar "perdido" (fue a propósito).
  void _cerrarSensor() {
    _verificacionTimer?.cancel();
    _verificacionTimer = null;
    _sensorSub?.cancel();
    _sensorSub = null;
    _sensorRepo.desconectar();
  }

  void _procesarLineaCruda(String linea) {
    final lectura = _interprete.procesar(linea);
    if (lectura != null) _lecturas.add(lectura);

    // El firmware se decide con los primeros paquetes; también después de
    // "no llegan datos", si al fin empiezan a llegar.
    if (_estadoSensor != EstadoSensor.verificando && _estadoSensor != EstadoSensor.sinDatos) return;
    switch (_interprete.firmware) {
      case EstadoFirmware.compatible:
        _verificacionTimer?.cancel();
        _cambiarEstado(EstadoSensor.listo);
      case EstadoFirmware.noCompatible:
        _verificacionTimer?.cancel();
        AppLogger.warning('Firmware del sensor no compatible con el contrato v1', tag: 'alerta');
        _cambiarEstado(EstadoSensor.noCompatible);
      case EstadoFirmware.verificando:
        break;
    }
  }
}
