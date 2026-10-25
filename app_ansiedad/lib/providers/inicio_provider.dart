import 'package:flutter/foundation.dart';
import '../app_config.dart';
import '../logger.dart';
import '../models/calibracion.dart';
import '../models/gad7.dart';
import '../models/sesion_resumen.dart';
import '../repositories/gad7_repository.dart';
import '../repositories/sesion_repository.dart';

enum EstadoInicio { cargando, listo, error }

/// Estado de la pantalla de Inicio (Fase M1c): la última sesión guardada y,
/// desde M3, la calibración de la línea base por origen (para la mascota).
///
/// "Sin mediciones" (lista vacía) y "error" (sin red, Render sin responder)
/// son estados distintos: un error nunca debe mostrarse como primer uso.
/// Si una recarga falla con datos ya cargados, se conservan los datos y se
/// deja [errorMsg] para que la UI lo avise sin vaciar la pantalla.
class InicioProvider extends ChangeNotifier {
  final String pacienteId;
  final SesionRepository _repo;
  final Gad7Repository _gad7Repo;

  final Listenable? _aviso;

  /// Con [aviso], se recarga solo cuando se guarda una sesión nueva.
  InicioProvider({required this.pacienteId, SesionRepository? repo, Gad7Repository? gad7Repo, Listenable? aviso})
      : _repo = repo ?? SesionRepository(),
        _gad7Repo = gad7Repo ?? Gad7Repository(),
        _aviso = aviso {
    _aviso?.addListener(cargar);
  }

  EstadoInicio _estado = EstadoInicio.cargando;
  EstadoInicio get estado => _estado;

  SesionResumen? _ultima;
  SesionResumen? get ultima => _ultima;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  bool _enCurso = false;
  bool get recargando => _enCurso;

  Map<String, Calibracion> _calibraciones = const {};

  /// Calibración de hoy del origen dado ('simulacion' | 'sensor'), o null si
  /// no se pudo cargar. Solo etapa y "día X de 7": nunca el estado.
  Calibracion? calibracionDe(String origen) => _calibraciones[origen];

  EstadoGad7? _gad7;

  /// Estado del GAD-7 (Fase M5a): ¿le toca?, ¿tiene especialista? Null si no
  /// se pudo cargar (la tarjeta no aparece). Nunca el resultado.
  EstadoGad7? get gad7 => _gad7;

  bool get sinMediciones => _estado == EstadoInicio.listo && _ultima == null;

  /// Regla de seguridad §2.3 sobre la última sesión.
  bool get spo2Bajo => _ultima != null && _ultima!.spo2Promedio < ConfigMedicion.spo2UmbralSeguridad;

  Future<void> cargar() async {
    if (_enCurso) return;
    _enCurso = true;
    _errorMsg = null;
    if (_estado != EstadoInicio.listo) _estado = EstadoInicio.cargando;
    notifyListeners();

    // La calibración va en paralelo y no es indispensable: si falla, Inicio se
    // ve como antes de M3 (sin el mensaje de la mascota) y no muestra error.
    final calibraciones = _cargarCalibraciones();
    // El GAD-7, igual: si falla, no hay tarjeta y no se muestra error.
    final gad7 = _cargarGad7();
    try {
      _ultima = await _repo.obtenerUltimaSesion(pacienteId);
      _estado = EstadoInicio.listo;
    } on RepositoryException catch (e) {
      _falla(e.mensaje);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar la última sesión', tag: 'inicio', error: e, stackTrace: stackTrace);
      _falla('Ocurrió un error inesperado.');
    }
    await calibraciones;
    await gad7;
    _enCurso = false;
    if (!_desechado) notifyListeners();
  }

  Future<void> _cargarCalibraciones() async {
    try {
      _calibraciones = await _repo.obtenerCalibraciones(pacienteId);
    } catch (e) {
      AppLogger.warning('No se pudo cargar la línea base', tag: 'inicio', error: e);
    }
  }

  Future<void> _cargarGad7() async {
    try {
      _gad7 = await _gad7Repo.obtenerEstado(pacienteId);
    } catch (e) {
      _gad7 = null;
      AppLogger.warning('No se pudo cargar el estado del GAD-7', tag: 'inicio', error: e);
    }
  }

  void _falla(String mensaje) {
    _errorMsg = mensaje;
    if (_estado != EstadoInicio.listo) _estado = EstadoInicio.error;
  }

  bool _desechado = false;

  @override
  void dispose() {
    _desechado = true;
    _aviso?.removeListener(cargar);
    super.dispose();
  }
}
