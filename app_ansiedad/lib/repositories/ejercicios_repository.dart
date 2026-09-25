import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../models/ejercicio_asignado.dart';
import 'repository_exception.dart';

/// Punto único de acceso a los ejercicios que el especialista asignó al
/// paciente (Fase 2c). El paciente solo lee: asignar se hace desde el portal.
class EjerciciosRepository {
  Future<List<EjercicioAsignado>> listar(String pacienteId) async {
    final res = await ApiClient.get(Uri.parse(AppConfig.urlEjerciciosPaciente(pacienteId)));
    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final data = jsonDecode(res.body ?? '[]') as List<dynamic>;
    return data.map((e) => EjercicioAsignado.fromJson(e as Map<String, dynamic>)).toList();
  }
}
