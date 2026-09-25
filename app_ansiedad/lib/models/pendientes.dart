/// Secciones de la app con indicador de pendiente (badge). El `name` es el
/// segmento de `POST /api/pendientes/:seccion/visto`.
enum SeccionPendiente { mensajes, ejercicios }

/// Conteo de lo nuevo que el paciente aún no ha visto (`GET /api/pendientes`).
class Pendientes {
  final int mensajes;
  final int ejercicios;

  const Pendientes({this.mensajes = 0, this.ejercicios = 0});

  factory Pendientes.fromJson(Map<String, dynamic> json) => Pendientes(
        mensajes: (json['mensajes'] as num?)?.toInt() ?? 0,
        ejercicios: (json['ejercicios'] as num?)?.toInt() ?? 0,
      );
}
