/// De dónde salen los datos de la sesión (columna `origen` de `sesiones_medicion`).
enum OrigenSesion {
  simulacion('simulacion'),
  sensor('sensor');

  final String valor;
  const OrigenSesion(this.valor);
}

/// Un punto de la serie de la sesión: promedios de un tramo de 5 s con señal
/// válida. Los tramos con mala señal no generan punto (huecos en `t`).
class PuntoSerie {
  /// Segundos desde `fechaInicio` (inicio del tramo).
  final int t;
  final double bpm;
  final double spo2;

  /// RMSSD de la ventana móvil que termina en este tramo (ms).
  final double hrv;

  const PuntoSerie({required this.t, required this.bpm, required this.spo2, required this.hrv});

  Map<String, dynamic> toJson() => {'t': t, 'bpm': bpm, 'spo2': spo2, 'hrv': hrv};
}

/// Una sesión de medición completa, lista para `POST /api/sesiones`.
///
/// `indiceCalidad` es interno (validación del sistema y especialista): la app
/// lo manda pero nunca lo muestra al paciente (DISENO_FLUJO_MEDICION.md §10).
class SesionMedicion {
  final DateTime fechaInicio;
  final int duracionTotalSeg;
  final int duracionValidaSeg;
  final double hrvRmssd;
  final double hrvMin;
  final double hrvMax;
  final double bpmPromedio;
  final int bpmMin;
  final int bpmMax;
  final double spo2Promedio;
  final int spo2Min;
  final int spo2Max;
  final double indiceCalidad;
  final List<PuntoSerie> serie;
  final OrigenSesion origen;

  const SesionMedicion({
    required this.fechaInicio,
    required this.duracionTotalSeg,
    required this.duracionValidaSeg,
    required this.hrvRmssd,
    required this.hrvMin,
    required this.hrvMax,
    required this.bpmPromedio,
    required this.bpmMin,
    required this.bpmMax,
    required this.spo2Promedio,
    required this.spo2Min,
    required this.spo2Max,
    required this.indiceCalidad,
    required this.serie,
    required this.origen,
  });

  /// Cuerpo de `POST /api/sesiones`. Lista cerrada de campos: sin
  /// `paciente_id` (sale del token). Los decimales van como números JSON, no
  /// como texto (validarSesion los rechaza si llegan como string). La fecha va
  /// en UTC con la `Z`, porque el backend exige zona horaria explícita.
  Map<String, dynamic> toJson() => {
        'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
        'duracion_total_seg': duracionTotalSeg,
        'duracion_valida_seg': duracionValidaSeg,
        'hrv_rmssd': hrvRmssd,
        'hrv_min': hrvMin,
        'hrv_max': hrvMax,
        'bpm_promedio': bpmPromedio,
        'bpm_min': bpmMin,
        'bpm_max': bpmMax,
        'spo2_promedio': spo2Promedio,
        'spo2_min': spo2Min,
        'spo2_max': spo2Max,
        'indice_calidad': indiceCalidad,
        'serie': serie.map((p) => p.toJson()).toList(),
        'origen': origen.valor,
      };
}
