/// Un mensaje del chat paciente–especialista, tal como lo maneja el backend
/// (tabla `mensajes_chat` vía Socket.io y `GET /api/mensajes/:pacienteId`).
class Mensaje {
  /// Id de la fila en `mensajes_chat`. Null solo en un mensaje que aún no
  /// guarda el servidor (los que se muestran siempre vienen del backend).
  final String? id;
  final String pacienteId;

  /// Quién escribió el mensaje (`mensajes_chat.remitente_id`): el paciente o
  /// su especialista. Lo pone el servidor, nunca el cliente. Puede venir null
  /// en mensajes antiguos, que siempre eran del paciente.
  final String? remitenteId;
  final String texto;
  final String tipoMensaje;
  final DateTime? fechaEnvio;

  Mensaje({
    this.id,
    required this.pacienteId,
    this.remitenteId,
    required this.texto,
    this.tipoMensaje = 'texto',
    this.fechaEnvio,
  });

  /// Remitente efectivo: los mensajes antiguos sin `remitente_id` los envió
  /// el paciente (antes solo la app podía escribir).
  String get remitenteEfectivo => remitenteId ?? pacienteId;

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        id: json['id']?.toString(),
        pacienteId: json['paciente_id']?.toString() ?? '',
        remitenteId: json['remitente_id']?.toString(),
        texto: json['texto']?.toString() ?? '',
        tipoMensaje: json['tipo_mensaje']?.toString() ?? 'texto',
        fechaEnvio: DateTime.tryParse(json['fecha_envio']?.toString() ?? '')?.toLocal(),
      );

  /// Lo que se manda por `enviar_mensaje`. Sin `remitente_id`: el servidor lo
  /// toma del token.
  Map<String, dynamic> toJson() => {
        'paciente_id': pacienteId,
        'texto': texto,
        'tipo_mensaje': tipoMensaje,
      };
}
