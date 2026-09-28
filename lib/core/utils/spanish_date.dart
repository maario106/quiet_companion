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
