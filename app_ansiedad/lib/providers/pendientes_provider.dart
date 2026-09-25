import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import '../models/pendientes.dart';
import '../repositories/pendientes_repository.dart';

/// Indicadores de pendiente (badges) de Mensajes y Ejercicios. Vive en
/// MainLayout, por encima de las pestañas, y consulta al backend al arrancar,
/// cada [_intervalo] mientras la app está en primer plano, y cuando MainLayout
/// se lo pide (cambio de pestaña, regreso de segundo plano).
///
/// Enfoque simple (sin estado por mensaje): cada sección tiene su marca de
/// "última apertura"; abrirla llama a [marcarVisto] y el contador vuelve a 0.
class PendientesProvider extends ChangeNotifier {
  final PendientesRepository _repo;

  static const Duration _intervalo = Duration(seconds: 45);

  PendientesProvider({PendientesRepository? repo}) : _repo = repo ?? PendientesRepository() {
    refrescar();
    iniciarSondeo();
  }

  Pendientes _pendientes = const Pendientes();
  int get mensajes => _pendientes.mensajes;
  int get ejercicios => _pendientes.ejercicios;

  Timer? _timer;
  bool _disposed = false;

  /// Sube con cada [marcarVisto]: una consulta que salió ANTES de marcar
  /// traería el conteo viejo y volvería a encender el badge ya limpiado, así
  /// que su resultado se descarta.
  int _version = 0;

  void iniciarSondeo() {
    _timer?.cancel();
    _timer = Timer.periodic(_intervalo, (_) => refrescar());
  }

  void detenerSondeo() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refrescar() async {
    final version = _version;
    try {
      final nuevos = await _repo.obtener();
      if (version != _version) return;
      _pendientes = nuevos;
      _notificar();
    } catch (e, stackTrace) {
      // El badge es secundario: si falla (sin red, cold start) se conserva el
      // último conteo y se reintenta en la siguiente vuelta, sin molestar.
      AppLogger.warning('No se pudieron consultar los pendientes', tag: 'pendientes', error: e);
      AppLogger.debug(stackTrace.toString(), tag: 'pendientes');
    }
  }

  /// El paciente abrió [seccion]: limpia su badge de inmediato (optimista) y
  /// mueve la marca en el servidor. Devuelve la marca ANTERIOR (null si no se
  /// pudo marcar), para resaltar lo que llegó desde la última apertura.
  Future<DateTime?> marcarVisto(SeccionPendiente seccion) async {
    _version++;
    _pendientes = seccion == SeccionPendiente.mensajes
        ? Pendientes(mensajes: 0, ejercicios: _pendientes.ejercicios)
        : Pendientes(mensajes: _pendientes.mensajes, ejercicios: 0);
    _notificar();

    try {
      return await _repo.marcarVisto(seccion);
    } catch (e) {
      AppLogger.warning('No se pudo marcar como vista la sección ${seccion.name}', tag: 'pendientes', error: e);
      return null;
    }
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    detenerSondeo();
    super.dispose();
  }
}
