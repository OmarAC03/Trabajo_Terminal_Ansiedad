import 'package:flutter/foundation.dart';
import '../app_config.dart';
import '../logger.dart';
import '../models/sesion_resumen.dart';
import '../repositories/sesion_repository.dart';

enum EstadoInicio { cargando, listo, error }

/// Estado de la pantalla de Inicio (Fase M1c): la última sesión guardada.
///
/// "Sin mediciones" (lista vacía) y "error" (sin red, Render sin responder)
/// son estados distintos: un error nunca debe mostrarse como primer uso.
/// Si una recarga falla con datos ya cargados, se conservan los datos y se
/// deja [errorMsg] para que la UI lo avise sin vaciar la pantalla.
class InicioProvider extends ChangeNotifier {
  final String pacienteId;
  final SesionRepository _repo;

  final Listenable? _aviso;

  /// Con [aviso], se recarga solo cuando se guarda una sesión nueva.
  InicioProvider({required this.pacienteId, SesionRepository? repo, Listenable? aviso})
      : _repo = repo ?? SesionRepository(),
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

  bool get sinMediciones => _estado == EstadoInicio.listo && _ultima == null;

  /// Regla de seguridad §2.3 sobre la última sesión.
  bool get spo2Bajo => _ultima != null && _ultima!.spo2Promedio < ConfigMedicion.spo2UmbralSeguridad;

  Future<void> cargar() async {
    if (_enCurso) return;
    _enCurso = true;
    _errorMsg = null;
    if (_estado != EstadoInicio.listo) _estado = EstadoInicio.cargando;
    notifyListeners();

    try {
      _ultima = await _repo.obtenerUltimaSesion(pacienteId);
      _estado = EstadoInicio.listo;
    } on RepositoryException catch (e) {
      _falla(e.mensaje);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar la última sesión', tag: 'inicio', error: e, stackTrace: stackTrace);
      _falla('Ocurrió un error inesperado.');
    }
    _enCurso = false;
    if (!_desechado) notifyListeners();
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
