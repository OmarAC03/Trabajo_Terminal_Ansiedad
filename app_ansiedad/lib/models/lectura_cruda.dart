/// Una lectura biométrica cruda tal como la manda el sensor por Bluetooth
/// (o la genera el modo simulación), antes de calcular el estado de ansiedad.
///
/// Los campos `rr`, `dedo` y `estable` son de la sesión de medición (Fase M1b):
/// `rr` trae los intervalos entre latidos (ms) ocurridos desde la lectura
/// anterior, y `dedo`/`estable` la calidad de señal. Si el paquete no los trae
/// (firmware actual), quedan en sus valores por defecto.
class LecturaCruda {
  final int bpm;
  final int spo2;
  final int hrv;
  final List<int> rr;
  final bool dedo;
  final bool estable;

  LecturaCruda({
    required this.bpm,
    required this.spo2,
    required this.hrv,
    this.rr = const [],
    this.dedo = true,
    this.estable = true,
  });

  /// Si el paquete del sensor no trae algún campo, se conserva el valor
  /// anterior en vez de resetear a 0 (mismo comportamiento que antes del refactor).
  factory LecturaCruda.fromJson(Map<String, dynamic> json, {required LecturaCruda anterior}) {
    return LecturaCruda(
      bpm: (json['bpm'] as num?)?.toInt() ?? anterior.bpm,
      spo2: (json['spo2'] as num?)?.toInt() ?? anterior.spo2,
      hrv: (json['hrv'] as num?)?.toInt() ?? anterior.hrv,
      rr: (json['rr'] as List<dynamic>?)?.map((v) => (v as num).toInt()).toList() ?? const [],
      dedo: json['dedo'] as bool? ?? true,
      estable: json['estable'] as bool? ?? true,
    );
  }
}
