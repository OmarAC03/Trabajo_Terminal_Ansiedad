import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../logger.dart';

/// Cambio de contraseña dentro de la app (Bloque 3, HU10 CA4). Mismas reglas
/// que el portal (PerfilEspecialista.js). No pasa por el backend: es solo
/// Firebase Auth.

const int minimoPassword = 6; // el mínimo de Firebase Auth

/// Lo que se necesita de Firebase; en las pruebas es un falso. Lanza
/// [FirebaseAuthException] con el código de Firebase.
abstract class CuentaPassword {
  Future<void> cambiar(String actual, String nueva);
}

class CuentaPasswordFirebase implements CuentaPassword {
  // Firebase exige una sesión reciente para updatePassword: reautenticar con
  // la contraseña actual evita requires-recent-login y confirma que quien la
  // cambia es el dueño de la cuenta.
  @override
  Future<void> cambiar(String actual, String nueva) async {
    final usuario = FirebaseAuth.instance.currentUser;
    final email = usuario?.email;
    if (usuario == null || email == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await usuario.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: actual));
    await usuario.updatePassword(nueva);
  }
}

/// Mensaje si los campos no sirven; null si se puede enviar.
String? errorCampos(String actual, String nueva, String confirmacion) {
  if (actual.isEmpty || nueva.isEmpty || confirmacion.isEmpty) return 'Completa los tres campos.';
  if (nueva.length < minimoPassword) return 'La nueva contraseña debe tener al menos $minimoPassword caracteres.';
  if (nueva != confirmacion) return 'La confirmación no coincide con la nueva contraseña.';
  if (nueva == actual) return 'La nueva contraseña debe ser distinta de la actual.';
  return null;
}

/// Código de Firebase → mensaje en español (los mismos del portal).
String mensajeErrorPassword(String codigo) {
  switch (codigo) {
    case 'wrong-password':
    case 'invalid-credential':
      return 'La contraseña actual no es correcta.';
    case 'weak-password':
      return 'La nueva contraseña es muy débil (mínimo $minimoPassword caracteres).';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
    case 'requires-recent-login':
      return 'Por seguridad, cierra sesión, vuelve a entrar e inténtalo de nuevo.';
    default:
      return 'No se pudo cambiar la contraseña. Inténtalo de nuevo.';
  }
}

class CambiarPasswordProvider extends ChangeNotifier {
  final CuentaPassword _cuenta;
  CambiarPasswordProvider({CuentaPassword? cuenta}) : _cuenta = cuenta ?? CuentaPasswordFirebase();

  bool _guardando = false;
  bool get guardando => _guardando;
  String? _error;
  String? get error => _error;
  bool _listo = false;
  bool get listo => _listo;

  /// true si se cambió. Las contraseñas nunca se registran en el log.
  Future<bool> cambiar(String actual, String nueva, String confirmacion) async {
    if (_guardando) return false;
    _listo = false;
    _error = errorCampos(actual, nueva, confirmacion);
    if (_error != null) {
      notifyListeners();
      return false;
    }
    _guardando = true;
    notifyListeners();
    try {
      await _cuenta.cambiar(actual, nueva);
      _listo = true;
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('No se pudo cambiar la contraseña (${e.code})', tag: 'perfil');
      _error = mensajeErrorPassword(e.code);
    } catch (e) {
      AppLogger.warning('Error inesperado al cambiar la contraseña', tag: 'perfil', error: e);
      _error = mensajeErrorPassword('');
    }
    _guardando = false;
    notifyListeners();
    return _listo;
  }
}
