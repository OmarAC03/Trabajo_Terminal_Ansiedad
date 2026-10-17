/// Línea base individual vista por el PACIENTE (Fase M3): solo la etapa de
/// calibración y el "día X de 7", para el mensaje de la mascota.
///
/// REGLA DE ORO: el paciente nunca ve la etiqueta del estado (normal /
/// elevados / altos), ni la banda, ni la z, ni si la FC quedó por encima de lo
/// habitual. El backend no se los manda (linea_base_vista.js) y, como segunda
/// barrera, estos modelos NO TIENEN esos campos: `fromJson` lee una lista
/// cerrada y descarta todo lo demás, aunque llegara en el JSON. No agregar
/// aquí `estado`, `z`, `banda`, `n` ni `fc_por_encima`.
library;

/// Etapa de la línea base: < 3 días con medición → calibrando; 3 a 6 →
/// preliminar; 7 → consolidada (DESARROLLO_FUNDAMENTADO.md §2.2).
enum EtapaBase {
  calibrando,
  preliminar,
  consolidada;

  /// Etapa desconocida (backend más nuevo): se trata como calibrando, que es
  /// el mensaje más neutro.
  static EtapaBase desde(Object? valor) => switch (valor) {
        'preliminar' => EtapaBase.preliminar,
        'consolidada' => EtapaBase.consolidada,
        _ => EtapaBase.calibrando,
      };
}

/// Por qué una sesión no se comparó con la línea base. Para el paciente solo
/// cambia el mensaje de la mascota; nunca se muestra como un "error".
enum MotivoSinComparar {
  calibrando,
  calidadBaja;

  static MotivoSinComparar? desde(Object? valor) => switch (valor) {
        'calibrando' => MotivoSinComparar.calibrando,
        'calidad_baja' => MotivoSinComparar.calidadBaja,
        _ => null,
      };
}

/// Calibración de un origen hoy (`GET /api/linea-base/:id` y
/// `data.calibracion` de `POST /api/sesiones`).
class Calibracion {
  final String origen;

  /// La de una medición hecha hoy.
  final EtapaBase etapa;

  /// La de la próxima medición de otro día.
  final EtapaBase etapaManana;

  /// "Día X de [diasObjetivo]": si ya midió hoy, hoy es su día X; si no, la
  /// próxima medición lo será. Tope en [diasObjetivo].
  final int diaCalibracion;
  final int diasObjetivo;
  final int diasConMedicion;
  final bool medidoHoy;

  /// Tenía mediciones de hace más de 30 días que ya vencieron (volvió tras un
  /// tiempo y la base se vuelve a calibrar).
  final bool hayHistorialVencido;

  const Calibracion({
    required this.origen,
    required this.etapa,
    required this.etapaManana,
    required this.diaCalibracion,
    required this.diasObjetivo,
    required this.diasConMedicion,
    required this.medidoHoy,
    required this.hayHistorialVencido,
  });

  factory Calibracion.fromJson(Map<String, dynamic> json) {
    final objetivo = _entero(json['dias_objetivo'], 7);
    return Calibracion(
      origen: (json['origen'] ?? '').toString(),
      etapa: EtapaBase.desde(json['etapa']),
      etapaManana: EtapaBase.desde(json['etapa_manana']),
      diaCalibracion: _entero(json['dia_calibracion'], 1).clamp(1, objetivo),
      diasObjetivo: objetivo,
      diasConMedicion: _entero(json['dias_con_medicion'], 0),
      medidoHoy: json['medido_hoy'] == true,
      hayHistorialVencido: json['hay_historial_vencido'] == true,
    );
  }

  /// `origenes` de `GET /api/linea-base/:id` → origen ('simulacion' |
  /// 'sensor') → calibración. Ignora lo que no sea un objeto.
  static Map<String, Calibracion> deOrigenes(Object? origenes) {
    if (origenes is! Map) return const {};
    return {
      for (final e in origenes.entries)
        if (e.value is Map) e.key.toString(): Calibracion.fromJson(Map<String, dynamic>.from(e.value as Map)),
    };
  }
}

/// Evaluación de UNA sesión, vista del paciente (`data.evaluacion` de
/// `POST /api/sesiones`): solo la etapa y el motivo, nunca el estado.
class EvaluacionSesion {
  final EtapaBase etapa;
  final MotivoSinComparar? motivo;

  const EvaluacionSesion({required this.etapa, this.motivo});

  factory EvaluacionSesion.fromJson(Map<String, dynamic> json) => EvaluacionSesion(
        etapa: EtapaBase.desde(json['etapa']),
        motivo: MotivoSinComparar.desde(json['motivo_sin_estado']),
      );
}

/// Lo que devuelve `POST /api/sesiones`: el id y, si el backend pudo
/// calcularlas, la evaluación de la sesión y la calibración de su origen
/// (null si no: la app muestra el mensaje genérico).
class SesionGuardada {
  final String id;
  final EvaluacionSesion? evaluacion;
  final Calibracion? calibracion;

  const SesionGuardada({required this.id, this.evaluacion, this.calibracion});

  /// [data] es `body['data']` de la respuesta.
  factory SesionGuardada.fromData(Map<String, dynamic> data) {
    final ev = data['evaluacion'];
    final cal = data['calibracion'];
    return SesionGuardada(
      id: (data['id'] ?? '').toString(),
      evaluacion: ev is Map ? EvaluacionSesion.fromJson(Map<String, dynamic>.from(ev)) : null,
      calibracion: cal is Map ? Calibracion.fromJson(Map<String, dynamic>.from(cal)) : null,
    );
  }
}

int _entero(Object? v, int porDefecto) => int.tryParse(v?.toString() ?? '') ?? porDefecto;
