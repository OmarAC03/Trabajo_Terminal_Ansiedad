/// Un ejercicio que el especialista asignó al paciente (tabla
/// `ejercicios_asignados`, `GET /api/ejercicios/:pacienteId`). Es una técnica
/// de la app ([tecnicaId], slug de `Tecnica.id`) O un texto libre
/// ([textoPersonalizado]), nunca ambos.
class EjercicioAsignado {
  final String id;
  final String? tecnicaId;
  final String? textoPersonalizado;
  final String? nota;
  final DateTime? fechaAsignacion;

  /// Calculado por el servidor contra `usuarios.ultima_apertura_ejercicios`.
  final bool visto;

  EjercicioAsignado({
    required this.id,
    this.tecnicaId,
    this.textoPersonalizado,
    this.nota,
    this.fechaAsignacion,
    this.visto = false,
  });

  factory EjercicioAsignado.fromJson(Map<String, dynamic> json) => EjercicioAsignado(
        id: json['id']?.toString() ?? '',
        tecnicaId: json['tecnica_id'] as String?,
        textoPersonalizado: json['texto_personalizado'] as String?,
        nota: json['nota'] as String?,
        fechaAsignacion: DateTime.tryParse(json['fecha_asignacion']?.toString() ?? '')?.toLocal(),
        visto: json['visto'] == true,
      );
}
