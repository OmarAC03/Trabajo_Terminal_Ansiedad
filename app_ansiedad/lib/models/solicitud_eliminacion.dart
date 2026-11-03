/// Solicitud de eliminación de cuenta del paciente (Bloque 1, paso 3:
/// RF-19 / RF-34). La atiende el administrador en el portal; el paciente no
/// la puede cancelar.
class SolicitudEliminacion {
  /// 'pendiente' | 'atendida'.
  final String estado;
  final DateTime fechaSolicitud;

  const SolicitudEliminacion({required this.estado, required this.fechaSolicitud});

  bool get pendiente => estado == 'pendiente';

  /// null si el JSON no trae una solicitud válida.
  static SolicitudEliminacion? fromJson(Object? json) {
    if (json is! Map) return null;
    final estado = json['estado'];
    final fecha = DateTime.tryParse('${json['fecha_solicitud']}');
    if (estado is! String || fecha == null) return null;
    return SolicitudEliminacion(estado: estado, fechaSolicitud: fecha.toLocal());
  }
}
