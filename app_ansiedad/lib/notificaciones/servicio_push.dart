import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logger.dart';
import '../repositories/dispositivos_repository.dart';

/// Notificaciones push (Bloque 3): el especialista escribió un mensaje o
/// asignó un ejercicio. Las envía el backend por FCM con un texto FIJO
/// (backend/notificaciones.js; regla de oro: nunca el contenido). Con la app
/// cerrada o en segundo plano las muestra el sistema; en primer plano no se
/// muestran (decisión D5): solo se refrescan los badges.
///
/// Este servicio se encarga del permiso (Android 13+), de registrar el token
/// del teléfono en el backend y de borrarlo al cerrar sesión.

enum PermisoNotificaciones { concedido, denegado, bloqueado }

/// Lo que se necesita de FCM y del sistema; en las pruebas es un falso.
abstract class FuentePush {
  Future<PermisoNotificaciones> estadoPermiso();
  Future<PermisoNotificaciones> pedirPermiso();
  Future<String?> obtenerToken();
  Stream<String> get tokenRenovado;
  Future<void> borrarToken();

  /// `tipo` de la notificación que abrió la app estando cerrada, o null.
  Future<String?> tipoDeArranque();

  /// `tipo` de cada notificación tocada con la app en segundo plano.
  Stream<String> get tiposAbiertos;

  /// Llegó una notificación con la app abierta (no se muestra).
  Stream<void> get enPrimerPlano;
}

/// Recuerda que ya se explicó y pidió el permiso, para no volver a insistir.
abstract class PreferenciasPush {
  Future<bool> yaPregunto();
  Future<void> marcarPregunto();
}

/// Pestaña de MainLayout que abre cada tipo de notificación (D8):
/// mensaje → Mensajes, ejercicio → Técnicas, gad7 (recordatorio local) → Inicio.
int? pestanaParaTipo(String? tipo) {
  switch (tipo) {
    case 'mensaje':
      return 2;
    case 'ejercicio':
      return 3;
    case 'gad7':
      return 0;
    default:
      return null;
  }
}

class ServicioPush {
  final FuentePush fuente;
  final DispositivosRepository repo;
  final PreferenciasPush prefs;

  ServicioPush({required this.fuente, required this.repo, required this.prefs});

  static ServicioPush? _instancia;
  static ServicioPush get instancia => _instancia ??= ServicioPush(
        fuente: FuentePushFirebase(),
        repo: DispositivosRepository(),
        prefs: PreferenciasPushLocales(),
      );

  StreamSubscription<String>? _renovacion;

  /// ¿Mostrar la explicación previa? Solo si no hay permiso y nunca se pidió.
  Future<bool> debePreguntar() async {
    if (await fuente.estadoPermiso() == PermisoNotificaciones.concedido) return false;
    return !(await prefs.yaPregunto());
  }

  /// Pide el permiso del sistema (una sola vez por instalación) y, si lo
  /// dan, registra el token.
  Future<PermisoNotificaciones> pedirPermiso() async {
    await prefs.marcarPregunto();
    final estado = await fuente.pedirPermiso();
    if (estado == PermisoNotificaciones.concedido) await registrar();
    return estado;
  }

  /// No volver a mostrar la explicación ("Ahora no").
  Future<void> posponer() => prefs.marcarPregunto();

  /// Al entrar a la app con sesión: registra el token si hay permiso, y
  /// cada token nuevo que dé FCM. Un fallo de red solo se registra en el log:
  /// se reintenta la próxima vez que se abra la app.
  Future<void> registrar() async {
    try {
      if (await fuente.estadoPermiso() != PermisoNotificaciones.concedido) return;
      final token = await fuente.obtenerToken();
      if (token != null) await _enviar(token);
      _renovacion ??= fuente.tokenRenovado.listen(_enviar);
    } catch (e) {
      AppLogger.warning('No se pudo preparar las notificaciones: $e', tag: 'push');
    }
  }

  Future<void> _enviar(String token) async {
    try {
      await repo.registrar(token);
    } catch (e) {
      AppLogger.warning('No se pudo registrar el dispositivo: $e', tag: 'push');
    }
  }

  /// Antes de `signOut` (después ya no hay sesión para llamar al backend):
  /// 1) se borra el token en el backend, 2) se invalida en FCM. Si (1) falla
  /// sin red, (2) hace que FCM lo rechace y el backend lo borra en el primer
  /// envío. Nunca lanza: cerrar sesión no debe fallar por esto.
  Future<void> cerrarSesion() async {
    await _renovacion?.cancel();
    _renovacion = null;
    try {
      final token = await fuente.obtenerToken();
      if (token != null) await repo.borrar(token);
    } catch (e) {
      AppLogger.warning('No se pudo borrar el dispositivo en el servidor: $e', tag: 'push');
    }
    await _invalidarLocal();
  }

  /// Cuenta suspendida o eliminada: el backend ya borró los tokens (y
  /// respondería 403); solo se invalida el de este teléfono.
  Future<void> limpiarPorBloqueo() async {
    await _renovacion?.cancel();
    _renovacion = null;
    await _invalidarLocal();
  }

  Future<void> _invalidarLocal() async {
    try {
      await fuente.borrarToken();
    } catch (e) {
      AppLogger.warning('No se pudo invalidar el token local: $e', tag: 'push');
    }
  }
}

class FuentePushFirebase implements FuentePush {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PermisoNotificaciones _traducir(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return PermisoNotificaciones.concedido;
    if (s.isPermanentlyDenied || s.isRestricted) return PermisoNotificaciones.bloqueado;
    return PermisoNotificaciones.denegado;
  }

  // POST_NOTIFICATIONS en Android 13+; en versiones anteriores ya viene
  // concedido salvo que el usuario lo apague en Ajustes.
  @override
  Future<PermisoNotificaciones> estadoPermiso() async => _traducir(await Permission.notification.status);

  @override
  Future<PermisoNotificaciones> pedirPermiso() async => _traducir(await Permission.notification.request());

  @override
  Future<String?> obtenerToken() => _fm.getToken();

  @override
  Stream<String> get tokenRenovado => _fm.onTokenRefresh;

  @override
  Future<void> borrarToken() => _fm.deleteToken();

  @override
  Future<String?> tipoDeArranque() async => (await _fm.getInitialMessage())?.data['tipo'] as String?;

  @override
  Stream<String> get tiposAbiertos => FirebaseMessaging.onMessageOpenedApp
      .map((m) => m.data['tipo'])
      .where((t) => t is String)
      .cast<String>();

  @override
  Stream<void> get enPrimerPlano => FirebaseMessaging.onMessage.map((_) {});
}

class PreferenciasPushLocales implements PreferenciasPush {
  static const _clave = 'push_permiso_preguntado';

  @override
  Future<bool> yaPregunto() async => (await SharedPreferences.getInstance()).getBool(_clave) ?? false;

  @override
  Future<void> marcarPregunto() async => (await SharedPreferences.getInstance()).setBool(_clave, true);
}
