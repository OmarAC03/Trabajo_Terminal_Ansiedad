import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../models/perfil.dart';
import 'repository_exception.dart';

/// Punto único de acceso a los datos de perfil (tabla `usuarios` en Supabase).
///
/// Igual que LecturaRepository: la UI/estado no llama a ApiClient ni parsea
/// JSON directamente, se lo pide a este repositorio.
class PerfilRepository {
  Future<Perfil> obtenerPerfil(String uid, {String emailRespaldo = ''}) async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlUsuario(uid)));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final data = jsonDecode(res.body ?? '{}') as Map<String, dynamic>;
    return Perfil.fromJson(data, emailRespaldo: emailRespaldo);
  }

  Future<void> actualizarNombre(String uid, String nombre) async {
    final res = await ApiClient.put(
      Uri.parse(AppConfig.urlUsuario(uid)),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"nombre": nombre}),
    );
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
  }
}
