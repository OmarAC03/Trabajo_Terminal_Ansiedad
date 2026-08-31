import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../avatar_widgets.dart';
import '../repositories/perfil_repository.dart';
import '../repositories/repository_exception.dart';

/// Maneja TODO el estado y la lógica de la pantalla de Perfil.
///
/// La UI ya no toca red ni FirebaseAuth directamente: le pide a este provider
/// y escucha sus cambios con notifyListeners(), igual que HistorialProvider.
class PerfilProvider extends ChangeNotifier {
  final PerfilRepository _repo;
  final String uid;

  PerfilProvider({required this.uid, PerfilRepository? repo}) : _repo = repo ?? PerfilRepository();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMsg;
  String? get errorMsg => _errorMsg;

  String _nombre = "";
  String get nombre => _nombre;

  String _email = "";
  String get email => _email;

  String _rol = "paciente";
  String get rol => _rol;

  TipoAvatar? _avatar;
  TipoAvatar? get avatar => _avatar;

  Future<void> cargar() async {
    _isLoading = true;
    _errorMsg = null;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      _errorMsg = "No se detectó una sesión activa.";
      notifyListeners();
      return;
    }

    // El avatar vive en Firebase (photoURL), no en Supabase.
    _avatar = avatarDesdePhotoUrl(user.photoURL);

    try {
      final perfil = await _repo.obtenerPerfil(uid, emailRespaldo: user.email ?? '');
      _nombre = perfil.nombre;
      _email = perfil.email;
      _rol = perfil.rol;
      _isLoading = false;
    } on RepositoryException catch (e) {
      _isLoading = false;
      // Aun si falla la carga en Supabase, mostramos al menos el correo de
      // Firebase para que la pantalla no quede vacía del todo.
      _email = user.email ?? '';
      _errorMsg = e.mensaje;
    } catch (_) {
      _isLoading = false;
      _email = user.email ?? '';
      _errorMsg = "Ocurrió un error inesperado.";
    }
    notifyListeners();
  }

  /// true si se guardó bien; false si falló (y ya revirtió el cambio optimista).
  Future<bool> actualizarAvatar(TipoAvatar nuevo) async {
    final anterior = _avatar;
    _avatar = nuevo; // optimista
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Sin sesión activa");
      await user.updatePhotoURL(avatarAPhotoUrl(nuevo));
      await user.reload();
      return true;
    } catch (_) {
      _avatar = anterior;
      notifyListeners();
      return false;
    }
  }

  /// null si se guardó bien; el mensaje de error si falló (y ya revirtió).
  Future<String?> editarNombre(String nuevoNombre) async {
    final anterior = _nombre;
    _nombre = nuevoNombre; // optimista
    notifyListeners();

    try {
      await _repo.actualizarNombre(uid, nuevoNombre);
      return null;
    } on RepositoryException catch (e) {
      _nombre = anterior;
      notifyListeners();
      return e.mensaje;
    } catch (_) {
      _nombre = anterior;
      notifyListeners();
      return "Ocurrió un error inesperado.";
    }
  }
}
