import 'dart:convert';
import '../api_client.dart';
import '../app_config.dart';
import '../contenido/privacidad_textos.dart';
import '../models/consentimiento.dart';
import 'repository_exception.dart';

export 'repository_exception.dart';

/// Acceso al consentimiento (`/api/consentimiento`, Bloque 1, paso 2).
class ConsentimientoRepository {
  /// Cuerpo con las versiones que esta app muestra. Se manda igual al
  /// registrarse (POST /api/usuarios) y al aceptar después.
  static Map<String, String> get versionesVigentes => {
        'version_aviso': TextosPrivacidad.versionAviso,
        'version_consentimiento': TextosPrivacidad.versionConsentimiento,
      };

  Future<EstadoConsentimiento> obtener() async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlConsentimiento));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);
    return EstadoConsentimiento.fromJson(Map<String, dynamic>.from(jsonDecode(res.body ?? '{}') as Map));
  }

  Future<EstadoConsentimiento> aceptar() async {
    final res = await ApiClient.post(
      Uri.parse(AppConfig.urlConsentimiento),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(versionesVigentes),
    );
    if (res.exito) {
      return EstadoConsentimiento.fromJson(Map<String, dynamic>.from(jsonDecode(res.body ?? '{}') as Map));
    }
    if (res.statusCode == 400) {
      // La versión de esta app ya no es la vigente en el servidor.
      throw RepositoryException('Hay una versión nueva del aviso. Actualiza la app para leerla y aceptarla.');
    }
    throw RepositoryException(res.mensajeUsuario);
  }
}
