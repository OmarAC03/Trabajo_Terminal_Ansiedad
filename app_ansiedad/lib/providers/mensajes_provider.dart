import 'dart:async';
import 'package:flutter/foundation.dart';
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

  void _conectar() {
    _sub = _chatRepo.conectar().listen((mensaje) {
      _mensajes.add(mensaje);
      notifyListeners();
    });
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
