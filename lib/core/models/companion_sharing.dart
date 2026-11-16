/// Qué ve el familiar del análisis. Lo elige el mayor y lo aplican las reglas.
/// Ordenado de menos a más.
enum CompanionSharing {
  none(
    label: 'Nada',
    description: 'Tu familiar solo sabe que guardas tus conversaciones.',
  ),
  wellbeing(
    label: 'Cómo me encuentro',
    description: 'Tu familiar ve cuándo hablamos y cómo te has sentido, '
        'pero no de qué hablamos.',
  ),
  full(
    label: 'Cómo me encuentro y de qué hablamos',
    description: 'Tu familiar ve cuándo hablamos, cómo te has sentido, '
        'un resumen breve de cada conversación y lo que recuerdo de ti.',
  );

  const CompanionSharing({required this.label, required this.description});

  /// Nombre del peldaño, lo que lee el mayor.
  final String label;

  /// Qué significa, en segunda persona y sin tecnicismos.
  final String description;

  /// Nivel por defecto cuando consiente un mayor vinculado.
  static const CompanionSharing byDefault = CompanionSharing.full;

  static CompanionSharing? fromNameOrNull(Object? raw) =>
      raw is String ? CompanionSharing.values.asNameMap()[raw] : null;
}
