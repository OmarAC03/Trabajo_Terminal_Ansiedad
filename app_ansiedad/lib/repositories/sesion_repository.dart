import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../logger.dart';
import '../models/sesion_detalle.dart';
import '../models/sesion_medicion.dart';
import '../models/sesion_resumen.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// La sesión pedida no existe o no es del paciente (el backend responde 404
/// igual en ambos casos).
class SesionNoEncontrada extends RepositoryException {
  SesionNoEncontrada() : super('Esta medición ya no está disponible.');
}

/// Acceso a las sesiones de medición (`/api/sesiones`, Fase M1).
class SesionRepository {
  /// Máximo que acepta el backend en `?limite=` (sin paginación por ahora).
  static const int limiteMaximo = 200;

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

  /// Sesiones del paciente, de la más reciente a la más antigua (sin serie).
  Future<List<SesionResumen>> obtenerSesiones(String pacienteId, {int limite = limiteMaximo}) async {
    final url = Uri.parse('${AppConfig.urlSesionesPaciente(pacienteId)}?limite=$limite');
    final res = await ApiClient.get(url);

    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final List<dynamic> data = jsonDecode(res.body ?? '[]');
    return data.map((e) => SesionResumen.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// La sesión más reciente del paciente, o null si todavía no tiene ninguna.
  Future<SesionResumen?> obtenerUltimaSesion(String pacienteId) async {
    final sesiones = await obtenerSesiones(pacienteId, limite: 1);
    return sesiones.isEmpty ? null : sesiones.first;
  }

  /// Detalle con la serie. Lanza [SesionNoEncontrada] si el backend responde 404.
  Future<SesionDetalle> obtenerDetalle(String pacienteId, String sesionId) async {
    final url = Uri.parse('${AppConfig.urlSesionesPaciente(pacienteId)}/$sesionId');
    final res = await ApiClient.get(url);

    if (res.statusCode == 404) throw SesionNoEncontrada();
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    return SesionDetalle.fromJson(jsonDecode(res.body ?? '{}') as Map<String, dynamic>);
  }
}
