import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/sesion_detalle.dart';
import '../repositories/sesion_repository.dart';

enum EstadoDetalle { cargando, listo, noEncontrada, error }

/// Estado del detalle de una sesión (Fase M1c): resumen, mínimos/máximos y serie.
/// Un 404 ([EstadoDetalle.noEncontrada]) es distinto de un error de red
/// ([EstadoDetalle.error]): solo el segundo tiene sentido reintentarlo.
class SesionDetalleProvider extends ChangeNotifier {
  final String pacienteId;
  final String sesionId;
  final SesionRepository _repo;

  SesionDetalleProvider({required this.pacienteId, required this.sesionId, SesionRepository? repo})
      : _repo = repo ?? SesionRepository();

  EstadoDetalle _estado = EstadoDetalle.cargando;
  EstadoDetalle get estado => _estado;

  SesionDetalle? _detalle;
  SesionDetalle? get detalle => _detalle;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  Future<void> cargar() async {
    _estado = EstadoDetalle.cargando;
    _errorMsg = null;
    notifyListeners();

    try {
      _detalle = await _repo.obtenerDetalle(pacienteId, sesionId);
      _estado = EstadoDetalle.listo;
    } on SesionNoEncontrada catch (e) {
      _estado = EstadoDetalle.noEncontrada;
      _errorMsg = e.mensaje;
    } on RepositoryException catch (e) {
      _estado = EstadoDetalle.error;
      _errorMsg = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar el detalle de la sesión', tag: 'historial', error: e, stackTrace: stackTrace);
      _estado = EstadoDetalle.error;
      _errorMsg = 'Ocurrió un error inesperado.';
    }
    if (!_desechado) notifyListeners();
  }

  bool _desechado = false;

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
