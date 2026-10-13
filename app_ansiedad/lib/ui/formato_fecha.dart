const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool _esAyer(DateTime fecha, DateTime ahora) => mismoDia(fecha, DateTime(ahora.year, ahora.month, ahora.day - 1));

/// "9:30"
String horaCorta(DateTime fecha) => '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';

/// Fecha relativa corta: "hoy 9:30", "ayer 20:15" o "lun 12 oct, 9:30".
/// [ahora] se recibe para poder probarla.
String fechaRelativa(DateTime fecha, {required DateTime ahora}) {
  final hora = horaCorta(fecha);
  if (mismoDia(fecha, ahora)) return 'hoy $hora';
  if (_esAyer(fecha, ahora)) return 'ayer $hora';
  return '${_dias[fecha.weekday - 1]} ${fecha.day} ${_meses[fecha.month - 1]}, $hora';
}

/// Encabezado de un día en el Historial: "Hoy", "Ayer", "lun 12 oct" (con el
/// año si no es el actual).
String etiquetaDia(DateTime dia, {required DateTime ahora}) {
  if (mismoDia(dia, ahora)) return 'Hoy';
  if (_esAyer(dia, ahora)) return 'Ayer';
  final base = '${_dias[dia.weekday - 1]} ${dia.day} ${_meses[dia.month - 1]}';
  return dia.year == ahora.year ? base : '$base ${dia.year}';
}

/// "45 s", "3 min", "3 min 34 s".
String duracionCorta(int segundos) {
  if (segundos < 60) return '$segundos s';
  final resto = segundos % 60;
  return resto == 0 ? '${segundos ~/ 60} min' : '${segundos ~/ 60} min $resto s';
}

/// Segundos como "m:ss" (eje de las gráficas de la sesión).
String minSeg(int segundos) => '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
