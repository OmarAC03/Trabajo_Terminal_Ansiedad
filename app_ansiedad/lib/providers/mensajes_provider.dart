import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/mensaje.dart';
import '../repositories/chat_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/vinculacion_repository.dart';

/// Estados de la pantalla de chat.
enum EstadoChat { cargando, sinEspecialista, listo, error }

/// Maneja TODO el estado y la lógica de la pantalla de Mensajes (chat).
///
/// La UI ya no toca Socket.io directamente: le pide a este provider que
/// conecte y le mande el mensaje, y escucha sus cambios con
/// notifyListeners(), igual que HistorialProvider, PerfilProvider y
/// AlertaProvider.
class MensajesProvider extends ChangeNotifier {
  final ChatRepository _chatRepo;
  final VinculacionRepository _vinculacionRepo;
  final String pacienteId;

  MensajesProvider({
    required this.pacienteId,
    ChatRepository? chatRepo,
    VinculacionRepository? vinculacionRepo,
  })  : _chatRepo = chatRepo ?? ChatRepository(),
        _vinculacionRepo = vinculacionRepo ?? VinculacionRepository() {
    cargar();
  }

  EstadoChat _estado = EstadoChat.cargando;
  EstadoChat get estado => _estado;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  String? _especialistaNombre;
  String? get especialistaNombre => _especialistaNombre;

  final List<Mensaje> _mensajes = [];
  List<Mensaje> get mensajes => _mensajes;

  StreamSubscription<Mensaje>? _sub;
  bool _disposed = false;

  /// Verifica la vinculación, conecta el socket y trae el historial. Se puede
  /// volver a llamar (ej. al regresar de vincularse con un especialista).
  Future<void> cargar() async {
    _estado = EstadoChat.cargando;
    _errorMsg = null;
    _notificar();

    try {
      final vinculacion = await _vinculacionRepo.obtenerVinculacion();
      if (!vinculacion.vinculado) {
        _estado = EstadoChat.sinEspecialista;
        _notificar();
        return;
      }
      _especialistaNombre = vinculacion.especialistaNombre;

      // Conectar ANTES de pedir el historial: si llega un mensaje mientras se
      // carga, no se pierde (_agregar descarta duplicados por id).
      if (_sub == null) await _conectar();
      _agregar(await _chatRepo.obtenerHistorial(pacienteId));
      _estado = EstadoChat.listo;
    } on RepositoryException catch (e) {
      _estado = EstadoChat.error;
      _errorMsg = e.mensaje;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cargar el chat', tag: 'mensajes', error: e, stackTrace: stackTrace);
      _estado = EstadoChat.error;
      _errorMsg = "Ocurrió un error inesperado al abrir el chat.";
    }
    _notificar();
  }

  Future<void> _conectar() async {
    final stream = await _chatRepo.conectar();
    _sub = stream.listen(
      (mensaje) {
        // El servidor solo manda mensajes de esta conversación; el filtro es
        // una segunda defensa por si acaso.
        if (mensaje.pacienteId != pacienteId) return;
        _agregar([mensaje]);
        _notificar();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('Error en el stream de mensajes', tag: 'mensajes', error: error, stackTrace: stackTrace);
      },
    );
  }

  /// Agrega sin duplicar (por id) y mantiene el orden cronológico.
  void _agregar(List<Mensaje> nuevos) {
    for (final m in nuevos) {
      if (m.id != null && _mensajes.any((x) => x.id == m.id)) continue;
      _mensajes.add(m);
    }
    _mensajes.sort((a, b) => (a.fechaEnvio ?? DateTime(0)).compareTo(b.fechaEnvio ?? DateTime(0)));
  }

  /// Devuelve null si se envió, o el mensaje de error para mostrar.
  Future<String?> enviarMensaje(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;
    return _chatRepo.enviarMensaje(Mensaje(pacienteId: pacienteId, texto: limpio));
  }

  /// Los mensajes del especialista quedan a la izquierda aunque lleven el
  /// mismo `paciente_id`: se compara quién los envió, no de quién es el chat.
  bool esMio(Mensaje mensaje) => mensaje.remitenteEfectivo == pacienteId;

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _chatRepo.desconectar();
    super.dispose();
  }
}
