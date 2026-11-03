import 'dart:convert';

/// Cuentas bloqueadas (Bloque 1, paso 1: suspender / reactivar desde el
/// portal del admin). Lógica pura, sin Flutter ni red: la usa [ApiClient] y la
/// prueba `test/cuenta_bloqueada_test.dart`.
///
/// Mismos códigos que `backend/cuentas.js`: llegan como `{ error, codigo }`
/// con un 403 cuando la cuenta de la sesión ya no puede usar la API, aunque su
/// token siga vigente. La app entonces cierra la sesión y lo explica en el
/// login.
const Map<String, String> mensajesBloqueo = {
  'cuenta_suspendida': 'Tu cuenta está suspendida. Contacta al administrador.',
  'cuenta_eliminada': 'Esta cuenta fue eliminada.',
};

/// Código de bloqueo de una respuesta, o null si es cualquier otra cosa.
String? codigoBloqueo(int? statusCode, String? body) {
  if (statusCode != 403 || body == null) return null;
  try {
    final datos = jsonDecode(body);
    if (datos is! Map) return null;
    final codigo = datos['codigo'];
    return mensajesBloqueo.containsKey(codigo) ? codigo as String : null;
  } catch (_) {
    return null;
  }
}
