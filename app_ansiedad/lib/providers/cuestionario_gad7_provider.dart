import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/gad7.dart';
import '../repositories/gad7_repository.dart';

enum FaseGad7 { intro, pregunta, dificultad, enviando, gracias, error }

/// Conduce el cuestionario GAD-7 (Fase M5a): introducción → 7 preguntas →
/// dificultad (solo si marcó algún problema) → envío → agradecimiento.
///
/// Las respuestas viven en memoria hasta enviarse: si sale a medias no se
/// guarda nada. NO calcula el puntaje ni la severidad (el paciente nunca ve su
/// resultado; el backend lo calcula para el especialista).
class CuestionarioGad7Provider extends ChangeNotifier {
  final Gad7Repository _repo;

  CuestionarioGad7Provider({Gad7Repository? repo}) : _repo = repo ?? Gad7Repository();

  FaseGad7 _fase = FaseGad7.intro;
  FaseGad7 get fase => _fase;

  /// Pregunta actual (0–6) mientras [fase] es [FaseGad7.pregunta].
  int _indice = 0;
  int get indice => _indice;

  final List<int?> _respuestas = List<int?>.filled(RespuestaGad7.numItems, null);
  int? respuestaDe(int i) => _respuestas[i];

  int? _dificultad;
  int? get dificultad => _dificultad;

  EnvioGad7? _resultado;
  EnvioGad7? get resultado => _resultado;

  String? _error;
  String? get error => _error;

  bool get completo => _respuestas.every((r) => r != null);

  /// "Si marcó cualquier problema": al menos un ítem distinto de "De nada".
  bool get marcoAlgunProblema => _respuestas.any((r) => r != null && r > 0);

  /// Salir ahora perdería respuestas (se pide confirmación).
  bool get tieneRespuestasSinGuardar =>
      _fase != FaseGad7.intro && _fase != FaseGad7.gracias && _respuestas.any((r) => r != null);

  void comenzar() {
    if (_fase != FaseGad7.intro) return;
    _fase = FaseGad7.pregunta;
    _indice = 0;
    _notificar();
  }

  /// Marca la respuesta de la pregunta actual. La pantalla avanza sola un
  /// momento después con [siguienteDesde] (para que se vea la opción marcada).
  void elegir(int valor) {
    if (_fase != FaseGad7.pregunta || valor < 0 || valor > 3) return;
    _respuestas[_indice] = valor;
    _notificar();
  }

  /// Avanza desde la pregunta [desde]. Si la pantalla ya se movió (un segundo
  /// toque, o "Atrás" durante la pausa), no hace nada: así nunca se salta una
  /// pregunta.
  void siguienteDesde(int desde) {
    if (_desechado || _fase != FaseGad7.pregunta || _indice != desde || _respuestas[_indice] == null) return;
    if (_indice < RespuestaGad7.numItems - 1) {
      _indice++;
      _notificar();
    } else if (marcoAlgunProblema) {
      _fase = FaseGad7.dificultad;
      _notificar();
    } else {
      // Todo "De nada": la pregunta de dificultad no aplica.
      _dificultad = null;
      enviar();
    }
  }

  void atras() {
    switch (_fase) {
      case FaseGad7.dificultad:
        _fase = FaseGad7.pregunta;
        _indice = RespuestaGad7.numItems - 1;
      case FaseGad7.pregunta:
        if (_indice > 0) {
          _indice--;
        } else {
          _fase = FaseGad7.intro;
        }
      default:
        return;
    }
    _notificar();
  }

  void elegirDificultad(int valor) {
    if (_fase != FaseGad7.dificultad || valor < 0 || valor > 3) return;
    _dificultad = valor;
    _notificar();
  }

  void omitirDificultad() {
    if (_fase != FaseGad7.dificultad) return;
    _dificultad = null;
    enviar();
  }

  Future<void> enviar() async {
    if (!completo || _fase == FaseGad7.enviando || _fase == FaseGad7.gracias) return;
    _fase = FaseGad7.enviando;
    _error = null;
    _notificar();
    try {
      final respuesta = RespuestaGad7(items: _respuestas.cast<int>(), dificultad: _dificultad);
      _resultado = await _repo.enviar(respuesta);
      _fase = FaseGad7.gracias;
    } on RepositoryException catch (e) {
      _error = e.mensaje;
      _fase = FaseGad7.error;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al enviar el GAD-7', tag: 'gad7', error: e, stackTrace: stackTrace);
      _error = 'Ocurrió un error inesperado. Intenta de nuevo.';
      _fase = FaseGad7.error;
    }
    _notificar();
  }

  /// Tras un error, con las mismas respuestas.
  Future<void> reintentar() async {
    if (_fase != FaseGad7.error) return;
    await enviar();
  }

  bool _desechado = false;

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
