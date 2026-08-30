import '../app_config.dart';

/// Una lectura biométrica individual, tal como la devuelve el backend.
///
/// Reemplaza el uso de `Map<String, dynamic>` suelto que la pantalla de
/// Historial manejaba antes (item['bpm'], item['fecha_medicion']...), que era
/// propenso a errores de tipeo en las claves y sin seguridad de tipos.
class Lectura {
  final int bpm;
  final int spo2;
  final int hrv;
  final double scoreAnsiedad;
  final String estadoAnsiedadTexto; // 'Alta' | 'Moderada' | 'Baja'
  final DateTime? fechaMedicion;

  Lectura({
    required this.bpm,
    required this.spo2,
    required this.hrv,
    required this.scoreAnsiedad,
    required this.estadoAnsiedadTexto,
    required this.fechaMedicion,
  });

  /// El estado como enum central, con su color y helpers asociados.
  EstadoAnsiedad get estado => EstadoAnsiedadInfo.desdeTexto(estadoAnsiedadTexto);

  factory Lectura.fromJson(Map<String, dynamic> json) {
    return Lectura(
      bpm: _asInt(json['bpm']),
      spo2: _asInt(json['spo2']),
      hrv: _asInt(json['hrv']),
      scoreAnsiedad: _asDouble(json['score_ansiedad']),
      estadoAnsiedadTexto: (json['estado_ansiedad'] ?? 'Baja').toString(),
      fechaMedicion: DateTime.tryParse(json['fecha_medicion']?.toString() ?? '')?.toLocal(),
    );
  }

  static int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;
}
