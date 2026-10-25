/// Modelos del GAD-7 en la app del paciente (Fase M5a).
///
/// [EstadoGad7] tiene una lista CERRADA de campos: aunque el backend mandara
/// por error un puntaje o una severidad, aquí no hay dónde guardarlos (misma
/// triple barrera que la línea base de M3: backend, modelo y textos).
class EstadoGad7 {
  /// Le toca responder (nunca ha respondido o ya pasaron 14 días).
  final bool toca;

  /// Tiene especialista: sin él no puede responder (no se muestra la tarjeta).
  final bool vinculado;

  /// Día ('YYYY-MM-DD', hora de México) desde el que puede responder.
  final String? proximaFecha;
  final int diasRestantes;
  final DateTime? ultimaRespuesta;

  const EstadoGad7({
    required this.toca,
    required this.vinculado,
    this.proximaFecha,
    this.diasRestantes = 0,
    this.ultimaRespuesta,
  });

  factory EstadoGad7.fromJson(Map<String, dynamic> json) {
    final ultima = json['ultima_respuesta'];
    final dias = json['dias_restantes'];
    return EstadoGad7(
      toca: json['toca'] == true,
      vinculado: json['vinculado'] == true,
      proximaFecha: json['proxima_fecha'] is String ? json['proxima_fecha'] as String : null,
      diasRestantes: dias is num ? dias.toInt() : 0,
      ultimaRespuesta: ultima is String ? DateTime.tryParse(ultima)?.toLocal() : null,
    );
  }
}

/// Mostrar la tarjeta "Cuestionario quincenal" en Inicio: solo si se pudo
/// cargar el estado, le toca y tiene especialista.
bool mostrarTarjetaGad7(EstadoGad7? estado) => estado != null && estado.toca && estado.vinculado;

/// Lo que se envía a `POST /api/gad7`: las 7 respuestas (0–3) y la dificultad
/// (0–3 o null). El puntaje no se calcula ni se manda desde la app.
class RespuestaGad7 {
  static const int numItems = 7;

  final List<int> items;
  final int? dificultad;

  RespuestaGad7({required List<int> items, this.dificultad}) : items = List.unmodifiable(items) {
    if (items.length != numItems || items.any((v) => v < 0 || v > 3)) {
      throw ArgumentError('El GAD-7 lleva $numItems respuestas de 0 a 3.');
    }
    final d = dificultad;
    if (d != null && (d < 0 || d > 3)) throw ArgumentError('La dificultad va de 0 a 3.');
  }

  Map<String, dynamic> toJson() => {'items': items, 'dificultad': dificultad};
}

/// Resultado del envío, para la pantalla (nunca el puntaje).
enum EnvioGad7 {
  guardado,

  /// 409: ya había una respuesta reciente (p. ej. un reintento automático
  /// tras un timeout cuyo primer intento sí llegó).
  yaRespondido,
}
