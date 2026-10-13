import 'sesion_medicion.dart';
import 'sesion_resumen.dart';

/// Detalle de una sesión para el paciente
/// (`GET /api/sesiones/:pacienteId/:sesionId`): el resumen, los mínimos y
/// máximos, y la serie para graficar. No tiene `indice_calidad`: el backend no
/// lo manda al paciente y este modelo tampoco lo lee.
class SesionDetalle {
  final SesionResumen resumen;
  final double hrvMin;
  final double hrvMax;
  final int bpmMin;
  final int bpmMax;
  final int spo2Min;
  final int spo2Max;
  final List<PuntoSerie> serie;

  const SesionDetalle({
    required this.resumen,
    required this.hrvMin,
    required this.hrvMax,
    required this.bpmMin,
    required this.bpmMax,
    required this.spo2Min,
    required this.spo2Max,
    required this.serie,
  });

  factory SesionDetalle.fromJson(Map<String, dynamic> json) {
    final serie = (json['serie'] as List<dynamic>? ?? const [])
        .map((p) => PuntoSerie.fromJson(p as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    return SesionDetalle(
      resumen: SesionResumen.fromJson(json),
      hrvMin: SesionResumen.asDouble(json['hrv_min']),
      hrvMax: SesionResumen.asDouble(json['hrv_max']),
      bpmMin: SesionResumen.asInt(json['bpm_min']),
      bpmMax: SesionResumen.asInt(json['bpm_max']),
      spo2Min: SesionResumen.asInt(json['spo2_min']),
      spo2Max: SesionResumen.asInt(json['spo2_max']),
      serie: serie,
    );
  }
}
