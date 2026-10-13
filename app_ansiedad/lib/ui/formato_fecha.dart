const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Fecha relativa corta: "hoy 9:30", "ayer 20:15" o "lun 12 oct, 9:30".
/// [ahora] se recibe para poder probarla.
String fechaRelativa(DateTime fecha, {required DateTime ahora}) {
  final hora = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  if (mismoDia(fecha, ahora)) return 'hoy $hora';
  if (mismoDia(fecha, DateTime(ahora.year, ahora.month, ahora.day - 1))) return 'ayer $hora';
  return '${_dias[fecha.weekday - 1]} ${fecha.day} ${_meses[fecha.month - 1]}, $hora';
}
