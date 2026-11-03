import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/solicitud_eliminacion.dart';
import '../repositories/eliminacion_repository.dart';

/// Estado de la pantalla "Eliminar mi cuenta" (Bloque 1, paso 3).
class EliminarCuentaProvider extends ChangeNotifier {
  final EliminacionRepository _repo;

  EliminarCuentaProvider({EliminacionRepository? repo}) : _repo = repo ?? EliminacionRepository();

  bool _cargando = true;
  bool get cargando => _cargando;

  SolicitudEliminacion? _solicitud;
  SolicitudEliminacion? get solicitud => _solicitud;

  /// Ya hay una solicitud pendiente: no se puede enviar otra ni cancelarla.
  bool get yaSolicitada => _solicitud?.pendiente ?? false;

  /// Casilla "Entiendo que se borrarán mis datos".
  bool _entiende = false;
  bool get entiende => _entiende;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  bool _destruido = false;

  bool get puedeEnviar => !_cargando && !yaSolicitada && _entiende && !_enviando;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _notificar();
    try {
      _solicitud = await _repo.obtener();
    } on RepositoryException catch (e) {
      _error = e.mensaje;
    } catch (e, st) {
      AppLogger.error('Error al consultar la solicitud de eliminación', tag: 'eliminacion', error: e, stackTrace: st);
      _error = 'No se pudo consultar tu solicitud. Intenta de nuevo.';
    }
    _cargando = false;
    _notificar();
  }

  void marcarEntiende(bool valor) {
    _entiende = valor;
    _notificar();
  }

  /// Devuelve true si la solicitud quedó registrada.
  Future<bool> solicitar() async {
    if (!puedeEnviar) return false;
    _enviando = true;
    _error = null;
    _notificar();
    try {
      _solicitud = await _repo.solicitar();
    } on RepositoryException catch (e) {
      _error = e.mensaje;
    } catch (e, st) {
      AppLogger.error('Error al solicitar la eliminación', tag: 'eliminacion', error: e, stackTrace: st);
      _error = 'No se pudo enviar tu solicitud. Intenta de nuevo.';
    }
    _enviando = false;
    _notificar();
    return yaSolicitada;
  }

  void _notificar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }
}
