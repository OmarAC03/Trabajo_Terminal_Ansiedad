import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/ejercicio_asignado.dart';
import '../models/pendientes.dart';
import '../repositories/ejercicios_repository.dart';
import '../repositories/repository_exception.dart';

/// Estado de la pantalla "Ejercicios asignados por tu especialista". Mismo
/// patrón que HistorialProvider/VinculacionProvider: la UI no toca red.
class EjerciciosProvider extends ChangeNotifier {
  final EjerciciosRepository _repo;
  final String pacienteId;

  /// Marca la sección como vista y devuelve la marca anterior
  /// (PendientesProvider.marcarVisto).
  final Future<DateTime?> Function(SeccionPendiente) _marcarVisto;

  EjerciciosProvider({
    required this.pacienteId,
    required Future<DateTime?> Function(SeccionPendiente) marcarVisto,
    EjerciciosRepository? repo,
  })  : _marcarVisto = marcarVisto,
        _repo = repo ?? EjerciciosRepository() {
    cargar();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  List<EjercicioAsignado> _ejercicios = [];
  List<EjercicioAsignado> get ejercicios => _ejercicios;

  /// Marca de la apertura anterior: lo asignado después es "Nuevo".
  DateTime? _vistoHasta;
  bool _disposed = false;

  /// Marca PRIMERO y lista DESPUÉS: así nada asignado entre ambas llamadas se
  /// queda marcado como visto sin haberse mostrado.
  Future<void> cargar() async {
    _isLoading = true;
    _errorMsg = null;
    _notificar();

    try {
      _vistoHasta = await _marcarVisto(SeccionPendiente.ejercicios);
      _ejercicios = await _repo.listar(pacienteId);
    } on RepositoryException catch (e) {
      _errorMsg = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar ejercicios asignados', tag: 'ejercicios', error: e, stackTrace: stackTrace);
      _errorMsg = "Ocurrió un error inesperado.";
    }
    _isLoading = false;
    _notificar();
  }

  /// Si no se pudo marcar (sin marca anterior), se usa el `visto` del servidor.
  bool esNuevo(EjercicioAsignado e) {
    final hasta = _vistoHasta;
    if (hasta == null || e.fechaAsignacion == null) return !e.visto;
    return e.fechaAsignacion!.isAfter(hasta);
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
