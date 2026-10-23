/// Una lectura biométrica cruda, un segundo de señal: la arma el intérprete
/// del sensor a partir del paquete del ESP32 (`repositories/interprete_sensor.dart`,
/// contrato en `CONTRATO_SENSOR.md`) o la genera el modo simulación.
///
/// `rr` trae los intervalos entre latidos (ms) ocurridos desde la lectura
/// anterior, y `dedo`/`estable` la calidad de señal (Fase M1b).
/// `cortaCadenaRr` (Fase M7a) avisa que antes de esta lectura se perdieron
/// paquetes del sensor: su primer RR no se resta contra el último anterior.
class LecturaCruda {
  final int bpm;
  final int spo2;
  final int hrv;
  final List<int> rr;
  final bool dedo;
  final bool estable;
  final bool cortaCadenaRr;

  LecturaCruda({
    required this.bpm,
    required this.spo2,
    required this.hrv,
    this.rr = const [],
    this.dedo = true,
    this.estable = true,
    this.cortaCadenaRr = false,
  });
}
