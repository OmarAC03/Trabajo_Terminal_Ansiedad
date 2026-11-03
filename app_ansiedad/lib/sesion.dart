import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'cuenta_bloqueada.dart';
import 'logger.dart';

/// Cierre de sesión forzado desde fuera de las pantallas (Bloque 1, paso 1).
///
/// Cuando el backend responde que la cuenta está suspendida o eliminada,
/// [ApiClient] llama a [cerrarPorBloqueo]: cierra la sesión de Firebase y deja
/// la app en [AuthGate] (que mostrará el login) sin importar qué pantalla
/// estaba abierta. El login toma el aviso con [tomarAvisoCierre].
class Sesion {
  Sesion._();

  /// Lo usa el [MaterialApp] de `main.dart`, para poder navegar sin `context`.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static String? _avisoCierre;
  static bool _cerrando = false;

  /// Devuelve el aviso pendiente (una sola vez) o null.
  static String? tomarAvisoCierre() {
    final aviso = _avisoCierre;
    _avisoCierre = null;
    return aviso;
  }

  static Future<void> cerrarPorBloqueo(String codigo) async {
    // Varias peticiones pueden recibir el 403 a la vez: se cierra una vez.
    if (_cerrando || FirebaseAuth.instance.currentUser == null) return;
    _cerrando = true;
    try {
      AppLogger.info('Sesión cerrada por el servidor ($codigo)', tag: 'sesion');
      _avisoCierre = mensajesBloqueo[codigo];
      await FirebaseAuth.instance.signOut();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } finally {
      _cerrando = false;
    }
  }
}
