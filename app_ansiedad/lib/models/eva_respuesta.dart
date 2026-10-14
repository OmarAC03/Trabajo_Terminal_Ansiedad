/// Contexto opcional de la EVA: "¿Qué estabas haciendo?" (lista cerrada, sin
/// texto libre). `valor` es lo que acepta el backend (chk_eva_contexto);
/// `texto` es lo que ve el paciente.
enum ContextoEva {
  reposo('reposo', 'En reposo'),
  estudiando('estudiando', 'Estudiando'),
  antesExamen('antes_examen', 'Antes de un examen'),
  despuesEstresor('despues_estresor', 'Después de una situación estresante'),
  otro('otro', 'Otro');

  final String valor;
  final String texto;
  const ContextoEva(this.valor, this.texto);
}

/// Respuesta a la EVA post-medición (Fase M2, DESARROLLO_FUNDAMENTADO.md §4.1):
/// "¿Qué tan ansioso/a te sientes en este momento?". Deslizador continuo sin
/// números visibles; internamente 0–100 (0 = nada, 100 = la máxima ansiedad
/// imaginable), como los milímetros de la EVA de papel.
class EvaRespuesta {
  final int valor;
  final ContextoEva? contexto;

  EvaRespuesta({required this.valor, this.contexto})
      : assert(valor >= 0 && valor <= 100, 'La EVA va de 0 a 100');

  /// Desde la posición del deslizador (0.0 a 1.0).
  factory EvaRespuesta.desdeDeslizador(double posicion, {ContextoEva? contexto}) =>
      EvaRespuesta(valor: (posicion.clamp(0.0, 1.0) * 100).round(), contexto: contexto);

  /// Cuerpo de `POST /api/sesiones/:sesionId/eva`. Lista cerrada: `valor` y,
  /// solo si se eligió, `contexto` (validarEva rechaza cualquier otro campo).
  Map<String, dynamic> toJson() => {
        'valor': valor,
        if (contexto != null) 'contexto': contexto!.valor,
      };
}
