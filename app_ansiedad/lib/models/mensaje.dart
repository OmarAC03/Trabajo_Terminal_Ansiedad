/// Un mensaje del chat paciente–especialista, tal como lo maneja el backend
/// (tabla `mensajes_chat` vía Socket.io).
class Mensaje {
  final String pacienteId;
  final String texto;
  final String tipoMensaje;

  Mensaje({
    required this.pacienteId,
    required this.texto,
    this.tipoMensaje = 'texto',
  });

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        pacienteId: json['paciente_id']?.toString() ?? '',
        texto: json['texto']?.toString() ?? '',
        tipoMensaje: json['tipo_mensaje']?.toString() ?? 'texto',
      );

  Map<String, dynamic> toJson() => {
        'paciente_id': pacienteId,
        'texto': texto,
        'tipo_mensaje': tipoMensaje,
      };
}
