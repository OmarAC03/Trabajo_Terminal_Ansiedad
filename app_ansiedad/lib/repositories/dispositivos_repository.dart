import 'dart:convert';
import '../api_client.dart';
import '../app_config.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// Token de FCM de este teléfono en el backend (`/api/dispositivos`,
/// Bloque 3). El backend nunca devuelve los tokens, solo cuántos hay.
class DispositivosRepository {
  static const _json = {"Content-Type": "application/json"};

  Future<void> registrar(String token) async {
    final res = await ApiClient.put(Uri.parse(AppConfig.urlDispositivos),
        headers: _json, body: jsonEncode({'token': token}));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
  }

  /// Al cerrar sesión. El backend responde 204 aunque el token ya no esté.
  Future<void> borrar(String token) async {
    final res = await ApiClient.delete(Uri.parse(AppConfig.urlDispositivos),
        headers: _json, body: jsonEncode({'token': token}));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
  }
}
