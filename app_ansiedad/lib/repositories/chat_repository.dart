import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api_client.dart';
import '../app_config.dart';
import '../models/mensaje.dart';
import 'repository_exception.dart';

/// Encapsula la conexión Socket.io del chat paciente–especialista.
///
/// El provider no habla directo con `socket_io_client`: le pide a este
/// repositorio que conecte y escucha el stream de mensajes recibidos, igual
/// que SensorRepository con el stream de líneas del sensor.
class ChatRepository {
  IO.Socket? _socket;

  /// Historial de la conversación con el especialista vinculado actual
  /// (`GET /api/mensajes/:pacienteId`), en orden cronológico.
  Future<List<Mensaje>> obtenerHistorial(String pacienteId) async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlMensajesPaciente(pacienteId)));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final List<dynamic> data = jsonDecode(res.body ?? '[]');
    return data.map((e) => Mensaje.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Conecta el socket y devuelve un stream con cada mensaje que llega del
  /// servidor. El backend solo le manda a este socket los mensajes de SU
  /// conversación (sala privada por usuario).
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

  /// Envía el mensaje y espera la confirmación del servidor. Devuelve null si
  /// se guardó, o el motivo del rechazo para mostrárselo al usuario (antes
  /// un mensaje rechazado o fallido se perdía en silencio).
  Future<String?> enviarMensaje(Mensaje mensaje) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.value("Sin conexión con el chat. Intenta de nuevo en unos segundos.");
    }

    final completer = Completer<String?>();
    socket.emitWithAck('enviar_mensaje', mensaje.toJson(), ack: (data) {
      // Según la versión del cliente el ack llega como el objeto o como lista
      // de argumentos.
      final resp = data is List && data.isNotEmpty ? data.first : data;
      if (completer.isCompleted) return;
      if (resp is Map && resp['ok'] == true) {
        completer.complete(null);
      } else {
        final error = resp is Map ? resp['error'] : null;
        completer.complete(error is String ? error : "No se pudo enviar el mensaje.");
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => "El servidor no respondió. Revisa tu conexión e intenta de nuevo.",
    );
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
