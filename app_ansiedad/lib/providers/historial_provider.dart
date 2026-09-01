import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/lectura.dart';
import '../models/resumen_dia.dart';
import '../repositories/lectura_repository.dart';

/// Estados posibles de la pantalla, explícitos en vez de varios bool sueltos.
enum EstadoCarga { inicial, cargando, listo, error }

/// Maneja TODO el estado y la lógica de la pantalla de Historial.
///
/// La UI ya no calcula nada ni llama a la red: le pide a este provider y
/// escucha sus cambios con notifyListeners(). Esto separa la lógica (testeable
/// sin UI) de la presentación (widgets tontos que solo dibujan).
class HistorialProvider extends ChangeNotifier {
  final LecturaRepository _repo;
  final String pacienteId;

  HistorialProvider({required this.pacienteId, LecturaRepository? repo})
      : _repo = repo ?? LecturaRepository();

  // 'dia' | 'semana' | 'mes'
  String _periodo = 'dia';
  String get periodo => _periodo;

  EstadoCarga _estado = EstadoCarga.inicial;
  EstadoCarga get estado => _estado;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  List<Lectura> _lecturasHoy = [];
  List<Lectura> get lecturasHoy => _lecturasHoy;

  List<ResumenDia> _periodoActual = [];
  List<ResumenDia> get periodoActual => _periodoActual;

  List<ResumenDia> _periodoAnterior = [];

  Future<void> cambiarPeriodo(String nuevo) async {
    if (_periodo == nuevo) return;
    _periodo = nuevo;
    await cargar();
  }

  Future<void> cargar() async {
    if (pacienteId.isEmpty) {
      _estado = EstadoCarga.error;
      _errorMsg = "No se detectó una sesión activa.";
      notifyListeners();
      return;
    }

    _estado = EstadoCarga.cargando;
    _errorMsg = null;
    notifyListeners();

    try {
      if (_periodo == 'dia') {
        _lecturasHoy = await _repo.obtenerLecturasDeHoy(pacienteId);
      } else {
        final r = await _repo.obtenerResumen(pacienteId, _periodo);
        final corte = DateTime.now().subtract(Duration(days: r.diasPorPeriodo));
        _periodoActual = r.serie.where((x) => x.dia.isAfter(corte)).toList();
        _periodoAnterior = r.serie.where((x) => !x.dia.isAfter(corte)).toList();
      }
      _estado = EstadoCarga.listo;
    } on RepositoryException catch (e) {
      _estado = EstadoCarga.error;
      _errorMsg = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar historial', tag: 'historial', error: e, stackTrace: stackTrace);
      _estado = EstadoCarga.error;
      _errorMsg = "Ocurrió un error inesperado. Desliza hacia abajo para reintentar.";
    }
    notifyListeners();
  }

  // ---------------- KPIs derivados (antes calculados en la UI) ----------------

  double promedioPonderado(num Function(ResumenDia) selector) {
    final lista = _periodoActual;
    if (lista.isEmpty) return 0;
    final totalReg = lista.fold<int>(0, (a, r) => a + r.totalRegistros);
    if (totalReg == 0) return 0;
    final suma = lista.fold<double>(0, (a, r) => a + selector(r) * r.totalRegistros);
    return suma / totalReg;
  }

  int get episodiosAltosTotales =>
      _periodoActual.fold<int>(0, (a, r) => a + r.episodiosAltos);

  /// % de cambio del score actual vs el periodo anterior, o null si no hay
  /// suficiente historial para comparar.
  double? get tendenciaScore {
    final actual = promedioPonderado((r) => r.scorePromedio);
    final anterior = _promedioAnterior((r) => r.scorePromedio);
    if (anterior == 0) return null;
    return ((actual - anterior) / anterior) * 100;
  }

  int get rachaSinEpisodiosAltos {
    final todos = [..._periodoActual, ..._periodoAnterior]
      ..sort((a, b) => b.dia.compareTo(a.dia));
    int racha = 0;
    for (final r in todos) {
      if (r.episodiosAltos == 0 && r.totalRegistros > 0) {
        racha++;
      } else if (r.totalRegistros > 0) {
        break;
      }
    }
    return racha;
  }

  double _promedioAnterior(num Function(ResumenDia) selector) {
    final lista = _periodoAnterior;
    if (lista.isEmpty) return 0;
    final totalReg = lista.fold<int>(0, (a, r) => a + r.totalRegistros);
    if (totalReg == 0) return 0;
    final suma = lista.fold<double>(0, (a, r) => a + selector(r) * r.totalRegistros);
    return suma / totalReg;
  }
}
