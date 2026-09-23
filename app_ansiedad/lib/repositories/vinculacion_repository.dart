import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../models/vinculacion.dart';
import 'repository_exception.dart';

/// Punto único de acceso a la vinculación paciente–especialista (Fase C del
/// sistema de vinculación; ver CONTEXTO_PROYECTO.md sección 4ter). Igual que
/// PerfilRepository: la UI/estado no llama a ApiClient ni parsea JSON.
class VinculacionRepository {
  Future<Vinculacion> obtenerVinculacion() async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlVinculacion));
    if (!res.exito) throw RepositoryException(_mensaje(res));

    final data = jsonDecode(res.body ?? '{}') as Map<String, dynamic>;
    return Vinculacion.fromJson(data);
  }

  /// Envía el código que el paciente escribió. Si el backend lo reconoce,
  /// devuelve la vinculación ya hecha.
  Future<Vinculacion> vincular(String codigo) async {
    final res = await ApiClient.post(
      Uri.parse(AppConfig.urlVinculacion),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"codigo_vinculacion": codigo}),
    );
    if (!res.exito) throw RepositoryException(_mensaje(res));

    final body = jsonDecode(res.body ?? '{}') as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return Vinculacion(
      vinculado: true,
      especialistaId: data['especialista_id'] as String?,
      especialistaNombre: data['especialista_nombre'] as String?,
    );
  }

  /// El backend manda un mensaje claro en "error" cuando el código no existe
  /// (ej. "Código de vinculación inválido."); se lo mostramos tal cual al
  /// paciente en vez del genérico "código 400" de ApiClient.
  String _mensaje(RespuestaRed res) {
    if (res.body != null) {
      try {
        final body = jsonDecode(res.body!) as Map<String, dynamic>;
        final error = body['error'];
        if (error is String && error.trim().isNotEmpty) return error;
      } catch (_) {
        // El cuerpo no era JSON válido: cae al mensaje genérico de abajo.
      }
    }
    return res.mensajeUsuario;
  }
}
