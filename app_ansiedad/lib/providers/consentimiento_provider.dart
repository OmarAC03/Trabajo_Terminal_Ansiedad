import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../repositories/consentimiento_repository.dart';

enum EstadoPuerta { cargando, pedirConsentimiento, continuar, error }

/// Puerta de consentimiento (Bloque 1, paso 2). Al entrar con sesión, decide
/// si el paciente pasa a la app o primero debe aceptar el aviso de privacidad
/// y el consentimiento. Especialistas y admins pasan directo (`requerido`
/// = false). Si no se puede consultar, NO deja pasar: muestra "Reintentar"
/// (el backend igual bloquea la captura, pero así nadie mide para nada).
class ConsentimientoProvider extends ChangeNotifier {
  final ConsentimientoRepository _repo;

  ConsentimientoProvider({ConsentimientoRepository? repo}) : _repo = repo ?? ConsentimientoRepository();

  EstadoPuerta _estado = EstadoPuerta.cargando;
  EstadoPuerta get estado => _estado;

  bool _aceptaAviso = false;
  bool _aceptaConsentimiento = false;
  bool get aceptaAviso => _aceptaAviso;
  bool get aceptaConsentimiento => _aceptaConsentimiento;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _error;
  String? get error => _error;

  bool _destruido = false;

  /// "Aceptar" se habilita solo con las dos casillas marcadas.
  bool get puedeAceptar => _aceptaAviso && _aceptaConsentimiento && !_enviando;

  Future<void> cargar() async {
    _estado = EstadoPuerta.cargando;
    _error = null;
    _notificar();
    try {
      final c = await _repo.obtener();
      _estado = c.puedeContinuar ? EstadoPuerta.continuar : EstadoPuerta.pedirConsentimiento;
    } on RepositoryException catch (e) {
      _estado = EstadoPuerta.error;
      _error = e.mensaje;
    } catch (e, st) {
      AppLogger.error('Error al consultar el consentimiento', tag: 'consentimiento', error: e, stackTrace: st);
      _estado = EstadoPuerta.error;
      _error = 'No se pudo comprobar tu consentimiento. Intenta de nuevo.';
    }
    _notificar();
  }

  void marcarAviso(bool valor) {
    _aceptaAviso = valor;
    _notificar();
  }

  void marcarConsentimiento(bool valor) {
    _aceptaConsentimiento = valor;
    _notificar();
  }

  Future<void> aceptar() async {
    if (!puedeAceptar) return;
    _enviando = true;
    _error = null;
    _notificar();
    try {
      final c = await _repo.aceptar();
      if (c.puedeContinuar) {
        _estado = EstadoPuerta.continuar;
      } else {
        _error = 'No se pudo registrar tu aceptación. Intenta de nuevo.';
      }
    } on RepositoryException catch (e) {
      _error = e.mensaje;
    } catch (e, st) {
      AppLogger.error('Error al aceptar el consentimiento', tag: 'consentimiento', error: e, stackTrace: st);
      _error = 'No se pudo registrar tu aceptación. Intenta de nuevo.';
    }
    _enviando = false;
    _notificar();
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
