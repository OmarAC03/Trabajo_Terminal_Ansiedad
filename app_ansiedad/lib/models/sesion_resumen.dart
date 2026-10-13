/// Lo que la pantalla de Inicio necesita de una sesión de medición guardada,
/// tal como la devuelve `GET /api/sesiones/:pacienteId` al paciente (sin
/// `indice_calidad` ni `serie`).
class SesionResumen {
  final String id;
  final DateTime fechaInicio;
  final double bpmPromedio;
  final double hrvRmssd;
  final double spo2Promedio;

  const SesionResumen({
    required this.id,
    required this.fechaInicio,
    required this.bpmPromedio,
    required this.hrvRmssd,
    required this.spo2Promedio,
  });

  /// El driver `pg` devuelve las columnas `numeric` como texto ("42.46"): se
  /// leen con `tryParse` sobre `toString()`, que sirve igual si llegan como número.
  factory SesionResumen.fromJson(Map<String, dynamic> json) {
    return SesionResumen(
      id: (json['id'] ?? '').toString(),
      fechaInicio: DateTime.parse(json['fecha_inicio'].toString()).toLocal(),
      bpmPromedio: _asDouble(json['bpm_promedio']),
      hrvRmssd: _asDouble(json['hrv_rmssd']),
      spo2Promedio: _asDouble(json['spo2_promedio']),
    );
  }

  static double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
}
