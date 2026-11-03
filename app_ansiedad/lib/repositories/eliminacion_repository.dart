import 'dart:convert';
import '../api_client.dart';
import '../app_config.dart';
import '../models/solicitud_eliminacion.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// Acceso a la solicitud de eliminación (`/api/solicitud-eliminacion`,
/// Bloque 1, paso 3).
class EliminacionRepository {
  /// La solicitud más reciente del paciente, o null si nunca pidió una.
  Future<SolicitudEliminacion?> obtener() async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlSolicitudEliminacion));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    final body = jsonDecode(res.body ?? '{}');
    return SolicitudEliminacion.fromJson(body is Map ? body['solicitud'] : null);
  }

  /// Envía la solicitud. Un 409 (ya había una pendiente, p. ej. el reintento
  /// automático de ApiClient tras un timeout) cuenta como enviada: se vuelve
  /// a consultar para mostrar la fecha real.
  Future<SolicitudEliminacion?> solicitar() async {
    final res = await ApiClient.post(
      Uri.parse(AppConfig.urlSolicitudEliminacion),
      headers: {"Content-Type": "application/json"},
      body: '{}',
    );
    if (res.statusCode == 409) return obtener();
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    final body = jsonDecode(res.body ?? '{}');
    return SolicitudEliminacion.fromJson(body is Map ? body['solicitud'] : null);
  }
}
