import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../logger.dart';
import '../models/gad7.dart';
import 'notificaciones_locales.dart';

/// Recordatorio LOCAL del GAD-7 (Bloque 3, decisión D1): lo programa el
/// teléfono, sin servidor (Render gratuito no tiene un proceso despierto).
///
/// D2: a las 10:00 (hora de México) del día que le toca, y uno más a los 3
/// días si sigue sin responder. Después, nada. Programación INEXACTA
/// (`inexactAllowWhileIdle`): sin SCHEDULE_EXACT_ALARM ni USE_EXACT_ALARM;
/// puede llegar unos minutos tarde. Sobrevive al reinicio del teléfono por el
/// receiver de arranque del plugin (AndroidManifest.xml).
///
/// Texto fijo y neutro, como los push: nunca el puntaje ni la severidad.
const tituloRecordatorio = 'Monitor ESCOM';
const textoRecordatorio = 'Ya puedes responder tu cuestionario quincenal';
const horaRecordatorio = 10;
const diasSegundoAviso = 3;
const intervaloGad7Dias = 14; // el de backend/gad7.js
const idsRecordatorio = [7001, 7002];
const zonaRecordatorio = 'America/Mexico_City';

/// 'YYYY-MM-DD' + días.
String sumarDias(String dia, int dias) {
  final p = dia.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]).add(Duration(days: dias));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime _alas10(String dia) {
  final p = dia.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2], horaRecordatorio);
}

/// Qué programar. Todo en "reloj de México" (DateTime sin zona).
///
/// `vence` es el día en que le tocó por primera vez en este ciclo. El
/// backend, cuando ya le toca, manda `proxima_fecha = hoy` cada día; por eso
/// se recuerda el `vence` anterior (`venceGuardado`): así el segundo aviso
/// queda a 3 días del vencimiento y no se recorre cada vez que se abre la app.
class PlanGad7 {
  final String? vence;
  final List<DateTime> fechas;
  const PlanGad7(this.vence, this.fechas);
}

PlanGad7 planGad7({required EstadoGad7? estado, required String? venceGuardado, required DateTime ahora}) {
  if (estado == null || !estado.vinculado || estado.proximaFecha == null) return const PlanGad7(null, []);
  final hoy = '${ahora.year.toString().padLeft(4, '0')}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';
  final String vence;
  if (!estado.toca) {
    vence = estado.proximaFecha!;
  } else {
    vence = (venceGuardado != null && venceGuardado.compareTo(hoy) <= 0) ? venceGuardado : hoy;
  }
  final fechas = [_alas10(vence), _alas10(sumarDias(vence, diasSegundoAviso))]
      .where((f) => f.isAfter(ahora))
      .toList();
  return PlanGad7(vence, fechas);
}

/// Lo que se necesita del sistema; en las pruebas es un falso.
abstract class ProgramadorRecordatorios {
  /// `relojMexico`: fecha y hora de pared en Ciudad de México.
  Future<void> programar(int id, DateTime relojMexico);
  Future<void> cancelar(int id);
  DateTime ahoraMexico();
  Future<String?> leerVence();
  Future<void> guardarVence(String? vence);
}

class RecordatorioGad7 {
  final ProgramadorRecordatorios programador;
  RecordatorioGad7(this.programador);

  static RecordatorioGad7? _instancia;
  static RecordatorioGad7 get instancia => _instancia ??= RecordatorioGad7(ProgramadorLocal());

  /// Con el estado que trae Inicio (GET /api/gad7/:id). Nunca lanza.
  Future<void> actualizar(EstadoGad7? estado) async {
    try {
      final plan = planGad7(
        estado: estado,
        venceGuardado: await programador.leerVence(),
        ahora: programador.ahoraMexico(),
      );
      for (final id in idsRecordatorio) {
        await programador.cancelar(id);
      }
      for (var i = 0; i < plan.fechas.length; i++) {
        await programador.programar(idsRecordatorio[i], plan.fechas[i]);
      }
      await programador.guardarVence(plan.vence);
    } catch (e) {
      AppLogger.warning('No se pudo programar el recordatorio del GAD-7: $e', tag: 'gad7');
    }
  }

  /// Recién respondido (o ya respondido hoy, 409): el siguiente toca en 14 días.
  Future<void> trasResponder() {
    final a = programador.ahoraMexico();
    final hoy = '${a.year.toString().padLeft(4, '0')}-${a.month.toString().padLeft(2, '0')}-${a.day.toString().padLeft(2, '0')}';
    return actualizar(EstadoGad7(toca: false, vinculado: true, proximaFecha: sumarDias(hoy, intervaloGad7Dias)));
  }

  /// Al cerrar sesión o si la cuenta se bloquea: no debe llegar a otra
  /// persona que use el teléfono.
  Future<void> cancelarTodo() async {
    try {
      for (final id in idsRecordatorio) {
        await programador.cancelar(id);
      }
      await programador.guardarVence(null);
    } catch (e) {
      AppLogger.warning('No se pudieron cancelar los recordatorios: $e', tag: 'gad7');
    }
  }
}

class ProgramadorLocal implements ProgramadorRecordatorios {
  static const _clave = 'gad7_recordatorio_vence';
  tz.Location? _zona;

  tz.Location get _ubicacion {
    if (_zona == null) {
      tzdata.initializeTimeZones();
      _zona = tz.getLocation(zonaRecordatorio);
    }
    return _zona!;
  }

  @override
  DateTime ahoraMexico() {
    final t = tz.TZDateTime.now(_ubicacion);
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  @override
  Future<void> programar(int id, DateTime relojMexico) async {
    await NotificacionesLocales.iniciar();
    final cuando = tz.TZDateTime(_ubicacion, relojMexico.year, relojMexico.month, relojMexico.day, relojMexico.hour);
    await NotificacionesLocales.plugin.zonedSchedule(
      id,
      tituloRecordatorio,
      textoRecordatorio,
      cuando,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificacionesLocales.canalRecordatorios.id,
          NotificacionesLocales.canalRecordatorios.name,
          channelDescription: NotificacionesLocales.canalRecordatorios.description,
          icon: 'ic_notificacion',
          // Sin texto en la pantalla de bloqueo más allá del aviso neutro.
          visibility: NotificationVisibility.private,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'gad7',
    );
  }

  @override
  Future<void> cancelar(int id) => NotificacionesLocales.plugin.cancel(id);

  @override
  Future<String?> leerVence() async => (await SharedPreferences.getInstance()).getString(_clave);

  @override
  Future<void> guardarVence(String? vence) async {
    final prefs = await SharedPreferences.getInstance();
    if (vence == null) {
      await prefs.remove(_clave);
    } else {
      await prefs.setString(_clave, vence);
    }
  }
}
