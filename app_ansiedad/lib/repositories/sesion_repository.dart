import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../logger.dart';
import '../models/sesion_medicion.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// Acceso a las sesiones de medición (`/api/sesiones`, Fase M1).
class SesionRepository {
  /// Sube una sesión completa y devuelve el id que le asignó el backend.
  Future<String> enviarSesion(SesionMedicion sesion) async {
    final res = await ApiClient.post(
      Uri.parse(AppConfig.urlSesiones),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(sesion.toJson()),
    );

    if (!res.exito) {
      // Un 400 aquí es un error de la app (la sesión ya se arma con las reglas
      // de validarSesion): se registra el detalle del backend para depurarlo.
      if (res.statusCode == 400) {
        AppLogger.error('El backend rechazó la sesión: ${res.body}', tag: 'sesiones');
      }
      throw RepositoryException(res.mensajeUsuario);
    }

    final Map<String, dynamic> body = jsonDecode(res.body ?? '{}');
    return (body['data']?['id'] ?? '').toString();
  }
}
