import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/vinculacion.dart';
import '../repositories/repository_exception.dart';
import '../repositories/vinculacion_repository.dart';

/// Maneja todo el estado de la sección "Especialista vinculado": carga el
/// estado actual y procesa el código que el paciente escribe. Mismo patrón
/// que PerfilProvider/HistorialProvider: la UI no toca red ni parsea JSON.
class VinculacionProvider extends ChangeNotifier {
  final VinculacionRepository _repo;

  VinculacionProvider({VinculacionRepository? repo}) : _repo = repo ?? VinculacionRepository();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isVinculando = false;
  bool get isVinculando => _isVinculando;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  Vinculacion _vinculacion = Vinculacion.sinVincular();
  Vinculacion get vinculacion => _vinculacion;

  Future<void> cargar() async {
    _isLoading = true;
    _errorMsg = null;
    notifyListeners();

    try {
      _vinculacion = await _repo.obtenerVinculacion();
    } on RepositoryException catch (e) {
      _errorMsg = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar vinculación', tag: 'vinculacion', error: e, stackTrace: stackTrace);
      _errorMsg = "Ocurrió un error inesperado.";
    }
    _isLoading = false;
    notifyListeners();
  }

  /// null si se vinculó bien (y ya actualizó `vinculacion`); el mensaje de
  /// error si falló.
  Future<String?> vincular(String codigo) async {
    _isVinculando = true;
    notifyListeners();

    try {
      _vinculacion = await _repo.vincular(codigo);
      return null;
    } on RepositoryException catch (e) {
      return e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al vincular especialista', tag: 'vinculacion', error: e, stackTrace: stackTrace);
      return "Ocurrió un error inesperado.";
    } finally {
      _isVinculando = false;
      notifyListeners();
    }
  }
}
