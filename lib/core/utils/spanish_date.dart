/// Fechas en castellano sin depender de `intl`: la app solo necesita un par
/// de formatos y todos sus textos son es-ES.
library;

const List<String> _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const List<String> _weekdays = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

/// "26 de septiembre de 2026".
String longSpanishDate(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';

/// "26 de septiembre".
String dayMonthSpanish(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]}';

/// "lunes".
String weekdaySpanish(DateTime date) => _weekdays[date.weekday - 1];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// "10:05".
String timeSpanish(DateTime date) =>
    '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

/// Cuándo fue algo, visto desde [now]: "hoy a las 10:05", "ayer a las 18:30",
/// "el lunes", "el 26 de septiembre".
String relativeSpanish(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return 'hoy a las ${timeSpanish(date)}';
  if (daysAgo == 1) return 'ayer a las ${timeSpanish(date)}';
  if (daysAgo < 7) return 'el ${weekdaySpanish(date)}';
  return 'el ${dayMonthSpanish(date)}';
}

/// "1 h 20 min", "15 min", "menos de 1 min".
String durationSpanish(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return 'menos de 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
