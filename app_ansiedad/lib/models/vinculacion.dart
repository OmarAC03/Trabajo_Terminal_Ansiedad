/// Estado de vinculación del paciente con su especialista, tal como lo
/// devuelve el backend (`GET`/`POST /api/vinculacion`; ver `especialista_id`
/// en la tabla `usuarios`, sección 4ter de CONTEXTO_PROYECTO.md).
class Vinculacion {
  final bool vinculado;
  final String? especialistaId;
  final String? especialistaNombre;

  Vinculacion({
    required this.vinculado,
    this.especialistaId,
    this.especialistaNombre,
  });

  factory Vinculacion.sinVincular() => Vinculacion(vinculado: false);

  factory Vinculacion.fromJson(Map<String, dynamic> json) {
    return Vinculacion(
      vinculado: json['vinculado'] == true,
      especialistaId: json['especialista_id'] as String?,
      especialistaNombre: json['especialista_nombre'] as String?,
    );
  }
}
