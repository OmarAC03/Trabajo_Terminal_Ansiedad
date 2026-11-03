/// Estado del consentimiento de la cuenta (GET /api/consentimiento, Bloque 1).
class EstadoConsentimiento {
  /// Solo el paciente lo requiere; especialista y admin pasan directo.
  final bool requerido;

  /// Aceptó la versión VIGENTE de los dos textos.
  final bool aceptado;
  final String? versionAviso;
  final String? versionConsentimiento;

  const EstadoConsentimiento({
    required this.requerido,
    required this.aceptado,
    this.versionAviso,
    this.versionConsentimiento,
  });

  /// Lectura estricta: si falta `requerido` o no es booleano se asume que SÍ
  /// se requiere y que NO se ha aceptado (mejor pedirlo de más que de menos).
  factory EstadoConsentimiento.fromJson(Map<String, dynamic> json) {
    final requerido = json['requerido'];
    final aceptado = json['aceptado'];
    return EstadoConsentimiento(
      requerido: requerido is bool ? requerido : true,
      aceptado: aceptado is bool ? aceptado : false,
      versionAviso: json['version_aviso'] is String ? json['version_aviso'] as String : null,
      versionConsentimiento:
          json['version_consentimiento'] is String ? json['version_consentimiento'] as String : null,
    );
  }

  /// ¿Puede usar la app sin pasar por la pantalla de consentimiento?
  bool get puedeContinuar => !requerido || aceptado;
}
