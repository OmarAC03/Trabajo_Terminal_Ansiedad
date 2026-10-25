import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../logger.dart';
import '../models/gad7.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// Acceso al GAD-7 periódico (`/api/gad7`, Fase M5a). El paciente solo recibe
/// su estado (¿le toca?, ¿tiene especialista?): nunca su resultado.
class Gad7Repository {
  Future<EstadoGad7> obtenerEstado(String pacienteId) async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlGad7Paciente(pacienteId)));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    final Map<String, dynamic> body = jsonDecode(res.body ?? '{}');
    final estado = body['estado'];
    return EstadoGad7.fromJson(estado is Map ? Map<String, dynamic>.from(estado) : const {});
  }

  /// Envía las respuestas. Un 409 cuenta como [EnvioGad7.yaRespondido]: ya hay
  /// una respuesta reciente (por ejemplo, el reintento automático de
  /// ApiClient tras un timeout cuyo primer intento sí llegó).
  Future<EnvioGad7> enviar(RespuestaGad7 respuesta) async {
    final res = await ApiClient.post(
      Uri.parse(AppConfig.urlGad7),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(respuesta.toJson()),
    );
    if (res.exito) return EnvioGad7.guardado;
    if (res.statusCode == 409) return EnvioGad7.yaRespondido;
    if (res.statusCode == 403) {
      throw RepositoryException('Para responder el cuestionario necesitas estar vinculado a un especialista.');
    }
    if (res.statusCode == 400) {
      // El cuerpo ya se arma con las reglas de validarGad7: un 400 es un error
      // de la app. Se registra solo el mensaje del backend (no trae valores).
      AppLogger.error('El backend rechazó el GAD-7: ${res.body}', tag: 'gad7');
      throw RepositoryException('No se pudieron guardar tus respuestas. Intenta de nuevo.');
    }
    throw RepositoryException(res.mensajeUsuario);
  }
}
