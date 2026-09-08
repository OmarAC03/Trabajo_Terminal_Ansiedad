import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../app_config.dart';
import '../models/mensaje.dart';

/// Encapsula la conexión Socket.io del chat paciente–especialista.
///
/// El provider no habla directo con `socket_io_client`: le pide a este
/// repositorio que conecte y escucha el stream de mensajes recibidos, igual
/// que SensorRepository con el stream de líneas del sensor.
class ChatRepository {
  IO.Socket? _socket;

  /// Conecta el socket y devuelve un stream con cada mensaje que llega del
  /// servidor (propios y de otros participantes del chat).
  ///
  /// El backend exige un token Firebase en el handshake (`auth.token`), por
  /// eso este método espera el idToken antes de armar las opciones del socket.
  Future<Stream<Mensaje>> conectar() async {
    final controller = StreamController<Mensaje>();
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final socket = IO.io(
      AppConfig.backendUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.on('recibir_mensaje', (data) {
      controller.add(Mensaje.fromJson(Map<String, dynamic>.from(data as Map)));
    });
    socket.on('connect_error', (error) {
      controller.addError(error ?? 'connect_error');
    });

    socket.connect();

    return controller.stream;
  }

  void enviarMensaje(Mensaje mensaje) {
    _socket?.emit('enviar_mensaje', mensaje.toJson());
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
