/// Lo que el familiar vinculado puede ver del análisis de las conversaciones
/// (ADR-0031). Lo elige solo el mayor, y lo hacen cumplir las reglas de
/// Firestore, no el panel: `wellbeing` abre `conversations`, `full` abre
/// además `conversationContents` y `memory`.
///
/// Ordenado de menos a más: el índice sirve como peldaño en Ajustes.
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

  /// Nivel que se aplica cuando el mayor vinculado consiente (decisión del
  /// autor, ADR-0031): el que más aporta a la familia, dicho en la pantalla de
  /// consentimiento y ajustable después.
  static const CompanionSharing byDefault = CompanionSharing.full;

  static CompanionSharing? fromNameOrNull(Object? raw) =>
      raw is String ? CompanionSharing.values.asNameMap()[raw] : null;
}
