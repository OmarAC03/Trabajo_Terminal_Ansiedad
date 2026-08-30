import 'dart:convert';
import '../app_config.dart';
import '../api_client.dart';
import '../models/lectura.dart';
import '../models/resumen_dia.dart';

/// Excepción de la capa de datos con un mensaje ya listo para el usuario.
/// La UI/estado la captura y muestra el mensaje sin tener que saber de HTTP.
class RepositoryException implements Exception {
  final String mensaje;
  RepositoryException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Punto único de acceso a los datos de lecturas biométricas.
///
/// Toda la app pide lecturas AQUÍ, no llamando a ApiClient directamente desde
/// las pantallas. Ventajas: la lógica de endpoints y de parseo vive en un solo
/// lugar, se puede cambiar el backend sin tocar la UI, y se puede sustituir por
/// un repositorio falso en pruebas (testing, Fase 3).
class LecturaRepository {
  /// Lecturas individuales de un paciente (más recientes primero).
  Future<List<Lectura>> obtenerLecturas(String pacienteId, {int limite = 200}) async {
    final url = Uri.parse('${AppConfig.urlLecturasPaciente(pacienteId)}?limite=$limite');
    final res = await ApiClient.get(url);

    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final List<dynamic> data = jsonDecode(res.body ?? '[]');
    return data
        .map((e) => Lectura.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Solo las lecturas de HOY, ordenadas ascendente por hora (para graficar).
  Future<List<Lectura>> obtenerLecturasDeHoy(String pacienteId) async {
    final todas = await obtenerLecturas(pacienteId, limite: 200);
    final hoy = DateTime.now();

    final soloHoy = todas.where((l) {
      final f = l.fechaMedicion;
      return f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    }).toList();

    soloHoy.sort((a, b) => (a.fechaMedicion ?? DateTime(0)).compareTo(b.fechaMedicion ?? DateTime(0)));
    return soloHoy;
  }

  /// Resúmenes diarios agregados. Devuelve la serie completa (periodo actual +
  /// anterior) que el backend entrega; la separación entre ambos periodos la
  /// hace la capa de estado, no el repositorio.
  Future<ResultadoResumen> obtenerResumen(String pacienteId, String periodo) async {
    final url = Uri.parse('${AppConfig.urlResumenPaciente(pacienteId)}?periodo=$periodo');
    final res = await ApiClient.get(url);

    if (!res.exito) throw RepositoryException(res.mensajeUsuario);

    final Map<String, dynamic> body = jsonDecode(res.body ?? '{}');
    final int diasPorPeriodo = body['dias_por_periodo'] ?? (periodo == 'mes' ? 30 : 7);
    final List<dynamic> serie = body['serie_completa'] ?? [];

    final resumenes = serie
        .map((e) => ResumenDia.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.dia.compareTo(b.dia));

    return ResultadoResumen(diasPorPeriodo: diasPorPeriodo, serie: resumenes);
  }
}

/// Contenedor del resultado del resumen: la serie de días + cuántos días abarca
/// un periodo (para que el estado separe "actual" de "anterior").
class ResultadoResumen {
  final int diasPorPeriodo;
  final List<ResumenDia> serie;
  ResultadoResumen({required this.diasPorPeriodo, required this.serie});
}
