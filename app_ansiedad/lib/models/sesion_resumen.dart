/// Una sesión de medición guardada, tal como la devuelve al paciente
/// `GET /api/sesiones/:pacienteId` (sin `indice_calidad` ni `serie`). La usan
/// Inicio (la última) y el Historial (la lista).
class SesionResumen {
  final String id;
  final DateTime fechaInicio;
  final int duracionTotalSeg;
  final double bpmPromedio;
  final double hrvRmssd;
  final double spo2Promedio;

  const SesionResumen({
    required this.id,
    required this.fechaInicio,
    required this.duracionTotalSeg,
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
      duracionTotalSeg: asInt(json['duracion_total_seg']),
      bpmPromedio: asDouble(json['bpm_promedio']),
      hrvRmssd: asDouble(json['hrv_rmssd']),
      spo2Promedio: asDouble(json['spo2_promedio']),
    );
  }

  static double asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
  static int asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
}
