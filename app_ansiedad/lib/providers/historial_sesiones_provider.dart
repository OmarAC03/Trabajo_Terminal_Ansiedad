import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/sesion_resumen.dart';
import '../repositories/sesion_repository.dart';
import '../ui/formato_fecha.dart';

enum EstadoHistorial { cargando, listo, error }

/// Sesiones de un mismo día (fecha local), en el orden en que llegaron.
class GrupoDia {
  final DateTime dia;
  final List<SesionResumen> sesiones;
  const GrupoDia(this.dia, this.sesiones);
}

/// Agrupa por día local respetando el orden de entrada (el backend las manda
/// de la más reciente a la más antigua).
List<GrupoDia> agruparPorDia(List<SesionResumen> sesiones) {
  final grupos = <GrupoDia>[];
  for (final s in sesiones) {
    final f = s.fechaInicio;
    if (grupos.isNotEmpty && mismoDia(grupos.last.dia, f)) {
      grupos.last.sesiones.add(s);
    } else {
      grupos.add(GrupoDia(DateTime(f.year, f.month, f.day), [s]));
    }
  }
  return grupos;
}

/// Estado de la pestaña Historial (Fase M1c): la lista de sesiones del paciente.
///
/// Igual que Inicio: "sin mediciones" (lista vacía) y "error" son estados
/// distintos, y una recarga fallida conserva la lista que ya se veía. Si se le
/// pasa [aviso], se recarga solo cuando se guarda una sesión nueva.
class HistorialSesionesProvider extends ChangeNotifier {
  final String pacienteId;
  final SesionRepository _repo;
  final Listenable? _aviso;

  HistorialSesionesProvider({required this.pacienteId, SesionRepository? repo, Listenable? aviso})
      : _repo = repo ?? SesionRepository(),
        _aviso = aviso {
    _aviso?.addListener(cargar);
  }

  EstadoHistorial _estado = EstadoHistorial.cargando;
  EstadoHistorial get estado => _estado;

  List<SesionResumen> _sesiones = const [];
  List<GrupoDia> _grupos = const [];
  List<GrupoDia> get grupos => _grupos;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  bool _enCurso = false;
  bool get recargando => _enCurso;

  bool get sinMediciones => _estado == EstadoHistorial.listo && _sesiones.isEmpty;

  Future<void> cargar() async {
    if (_enCurso) return;
    _enCurso = true;
    _errorMsg = null;
    if (_estado != EstadoHistorial.listo) _estado = EstadoHistorial.cargando;
    notifyListeners();

    try {
      _sesiones = await _repo.obtenerSesiones(pacienteId);
      _grupos = agruparPorDia(_sesiones);
      _estado = EstadoHistorial.listo;
    } on RepositoryException catch (e) {
      _falla(e.mensaje);
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar el historial de sesiones', tag: 'historial', error: e, stackTrace: stackTrace);
      _falla('Ocurrió un error inesperado.');
    }
    _enCurso = false;
    if (!_desechado) notifyListeners();
  }

  void _falla(String mensaje) {
    _errorMsg = mensaje;
    if (_estado != EstadoHistorial.listo) _estado = EstadoHistorial.error;
  }

  bool _desechado = false;

  @override
  void dispose() {
    _desechado = true;
    _aviso?.removeListener(cargar);
    super.dispose();
  }
}
