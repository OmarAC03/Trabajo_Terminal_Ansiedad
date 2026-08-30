/// Un resumen diario ya agregado por el backend (promedios y conteos de un día).
///
/// Antes esta clase vivía como `_ResumenDia` privada dentro de historial_screen.
/// Al sacarla a la capa de modelos, cualquier pantalla o servicio puede usarla,
/// y queda un solo lugar que define cómo se interpreta el JSON del backend.
class ResumenDia {
  final DateTime dia;
  final int bpmPromedio;
  final int spo2Promedio;
  final int hrvPromedio;
  final double scorePromedio;
  final int episodiosAltos;
  final int episodiosModerados;
  final int episodiosBajos;
  final int totalRegistros;

  ResumenDia({
    required this.dia,
    required this.bpmPromedio,
    required this.spo2Promedio,
    required this.hrvPromedio,
    required this.scorePromedio,
    required this.episodiosAltos,
    required this.episodiosModerados,
    required this.episodiosBajos,
    required this.totalRegistros,
  });

  factory ResumenDia.fromJson(Map<String, dynamic> json) {
    return ResumenDia(
      dia: DateTime.parse(json['dia']).toLocal(),
      bpmPromedio: _asInt(json['bpm_promedio']),
      spo2Promedio: _asInt(json['spo2_promedio']),
      hrvPromedio: _asInt(json['hrv_promedio']),
      scorePromedio: _asDouble(json['score_promedio']),
      episodiosAltos: _asInt(json['episodios_altos']),
      episodiosModerados: _asInt(json['episodios_moderados']),
      episodiosBajos: _asInt(json['episodios_bajos']),
      totalRegistros: _asInt(json['total_registros']),
    );
  }

  static int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
}
