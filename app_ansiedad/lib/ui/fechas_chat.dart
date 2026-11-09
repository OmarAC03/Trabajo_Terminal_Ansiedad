import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Fechas del chat (versión final, punto 3): separadores por día tipo
/// WhatsApp ("Hoy", "Ayer", "lunes 9 de noviembre") y la hora de cada mensaje,
/// siempre en hora de la Ciudad de México aunque el teléfono tenga otra zona.

const String zonaChat = 'America/Mexico_City';

tz.Location? _zona;
tz.Location get _ubicacion {
  if (_zona == null) {
    tzdata.initializeTimeZones();
    _zona = tz.getLocation(zonaChat);
  }
  return _zona!;
}

/// El mismo instante, como reloj de pared de la Ciudad de México (un
/// DateTime "local" sin zona, solo para mostrarlo y agrupar por día).
DateTime enHoraMexico(DateTime instante) {
  final t = tz.TZDateTime.from(instante.toUtc(), _ubicacion);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

const List<String> _diasLargos = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const List<String> _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hoy", "Ayer" o "lunes 9 de noviembre" (con " de 2025" si no es este año).
/// [dia] y [hoy] ya en hora de México.
String etiquetaDiaChat(DateTime dia, {required DateTime hoy}) {
  if (_mismoDia(dia, hoy)) return 'Hoy';
  if (_mismoDia(dia, DateTime(hoy.year, hoy.month, hoy.day - 1))) return 'Ayer';
  final base = '${_diasLargos[dia.weekday - 1]} ${dia.day} de ${_mesesLargos[dia.month - 1]}';
  return dia.year == hoy.year ? base : '$base de ${dia.year}';
}

/// "14:05" (24 h, como en el ejemplo). [hora] ya en hora de México.
String horaChat(DateTime hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

/// Un renglón del chat: un separador de día o un mensaje.
class ElementoChat<T> {
  final String? separador;
  final T? mensaje;

  /// Hora del mensaje ya formateada ('' si no tiene fecha).
  final String hora;
  const ElementoChat.separador(String this.separador)
      : mensaje = null,
        hora = '';
  const ElementoChat.mensaje(T this.mensaje, this.hora) : separador = null;
  bool get esSeparador => separador != null;
}

/// Intercala los separadores de día en [mensajes] (en orden cronológico).
/// Un mensaje sin fecha se queda en el día del anterior. [ahora] es el
/// instante actual (se recibe para poder probarlo).
List<ElementoChat<T>> conSeparadores<T>(
  List<T> mensajes,
  DateTime? Function(T) fecha, {
  required DateTime ahora,
}) {
  final hoy = enHoraMexico(ahora);
  final salida = <ElementoChat<T>>[];
  DateTime? diaActual;
  for (final m in mensajes) {
    final f = fecha(m);
    if (f == null) {
      salida.add(ElementoChat.mensaje(m, ''));
      continue;
    }
    final local = enHoraMexico(f);
    if (diaActual == null || !_mismoDia(diaActual, local)) {
      diaActual = local;
      salida.add(ElementoChat.separador(etiquetaDiaChat(local, hoy: hoy)));
    }
    salida.add(ElementoChat.mensaje(m, horaChat(local)));
  }
  return salida;
}
