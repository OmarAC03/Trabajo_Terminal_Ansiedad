import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../models/pendientes.dart';
import 'repository_exception.dart';

/// Punto único de acceso a los indicadores de pendiente (badges de Mensajes y
/// Ejercicios). Cada sección tiene su propia marca de "última apertura" en
/// `usuarios`; el backend cuenta lo que llegó después.
class PendientesRepository {
  Future<Pendientes> obtener() async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlPendientes));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    return Pendientes.fromJson(jsonDecode(res.body ?? '{}') as Map<String, dynamic>);
  }

  /// Marca la sección como vista "ahora" y devuelve la marca ANTERIOR (lo
  /// que llegó después de ella es lo "nuevo" para esta apertura).
  Future<DateTime?> marcarVisto(SeccionPendiente seccion) async {
    final res = await ApiClient.post(Uri.parse(AppConfig.urlPendienteVisto(seccion.name)));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    final data = jsonDecode(res.body ?? '{}') as Map<String, dynamic>;
    return DateTime.tryParse(data['anterior']?.toString() ?? '')?.toLocal();
  }
}
