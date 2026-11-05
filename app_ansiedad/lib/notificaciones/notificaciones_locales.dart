import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../logger.dart';

/// Plugin de notificaciones locales (Bloque 3), compartido por los canales de
/// Android y por el recordatorio del GAD-7.
///
/// Canales (Android 8+): el sistema los muestra en Ajustes con su nombre.
///  - `avisos`: mensajes y ejercicios que manda el backend por FCM (el
///    `channelId` que pone backend/notificaciones.js).
///  - `recordatorios`: el cuestionario quincenal (local, sin servidor).
class NotificacionesLocales {
  NotificacionesLocales._();

  static const canalAvisos = AndroidNotificationChannel(
    'avisos',
    'Avisos de tu especialista',
    description: 'Mensajes nuevos y ejercicios asignados. Nunca muestran su contenido.',
    importance: Importance.high,
  );

  static const canalRecordatorios = AndroidNotificationChannel(
    'recordatorios',
    'Recordatorios',
    description: 'Cuando toca responder el cuestionario quincenal.',
    importance: Importance.defaultImportance,
  );

  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;

  /// `tipo` de la notificación local tocada (payload), para abrir su pestaña.
  static final ValueNotifier<String?> tocada = ValueNotifier<String?>(null);

  /// En `main`, antes de `runApp`. Nunca lanza: sin canales, Android usa el
  /// de respaldo de FCM y la app funciona igual.
  static Future<void> iniciar() async {
    if (_listo) return;
    try {
      await plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('ic_notificacion')),
        onDidReceiveNotificationResponse: (r) => tocada.value = r.payload,
      );
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(canalAvisos);
      await android?.createNotificationChannel(canalRecordatorios);
      // Si un recordatorio abrió la app estando cerrada.
      final arranque = await plugin.getNotificationAppLaunchDetails();
      if (arranque?.didNotificationLaunchApp ?? false) tocada.value = arranque!.notificationResponse?.payload;
      _listo = true;
    } catch (e) {
      AppLogger.warning('No se pudieron preparar las notificaciones locales: $e', tag: 'push');
    }
  }
}
