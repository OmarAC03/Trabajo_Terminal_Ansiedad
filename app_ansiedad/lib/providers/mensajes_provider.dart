import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/mensaje.dart';
import '../repositories/chat_repository.dart';

/// Maneja TODO el estado y la lógica de la pantalla de Mensajes (chat).
///
/// La UI ya no toca Socket.io directamente: le pide a este provider que
/// conecte y le mande el mensaje, y escucha sus cambios con
/// notifyListeners(), igual que HistorialProvider, PerfilProvider y
/// AlertaProvider.
class MensajesProvider extends ChangeNotifier {
  final ChatRepository _chatRepo;
  final String pacienteId;

  MensajesProvider({
    required this.pacienteId,
    ChatRepository? chatRepo,
  }) : _chatRepo = chatRepo ?? ChatRepository() {
    _conectar();
  }

  final List<Mensaje> _mensajes = [];
  List<Mensaje> get mensajes => _mensajes;

  StreamSubscription<Mensaje>? _sub;

  Future<void> _conectar() async {
    final stream = await _chatRepo.conectar();
    _sub = stream.listen(
      (mensaje) {
        _mensajes.add(mensaje);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('Error en el stream de mensajes', tag: 'mensajes', error: error, stackTrace: stackTrace);
      },
    );
  }

  void enviarMensaje(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    _chatRepo.enviarMensaje(Mensaje(pacienteId: pacienteId, texto: limpio));
  }

  bool esMio(Mensaje mensaje) => mensaje.pacienteId == pacienteId;

  @override
  void dispose() {
    _sub?.cancel();
    _chatRepo.desconectar();
    super.dispose();
  }
}
