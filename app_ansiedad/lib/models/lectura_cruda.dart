/// Una lectura biométrica cruda tal como la manda el sensor por Bluetooth
/// (o la genera el modo simulación), antes de calcular el estado de ansiedad.
class LecturaCruda {
  final int bpm;
  final int spo2;
  final int hrv;

  LecturaCruda({required this.bpm, required this.spo2, required this.hrv});

  /// Si el paquete del sensor no trae algún campo, se conserva el valor
  /// anterior en vez de resetear a 0 (mismo comportamiento que antes del refactor).
  factory LecturaCruda.fromJson(Map<String, dynamic> json, {required LecturaCruda anterior}) {
    return LecturaCruda(
      bpm: (json['bpm'] as num?)?.toInt() ?? anterior.bpm,
      spo2: (json['spo2'] as num?)?.toInt() ?? anterior.spo2,
      hrv: (json['hrv'] as num?)?.toInt() ?? anterior.hrv,
    );
  }
}
