/// Plazos de la conversación del mayor (ADR-0034): cuándo se da por
/// terminada una conversación y cuánto se conserva lo analizado.
///
/// Los fija el familiar en modo vinculado y el propio mayor en modo
/// independiente. Solo existen estos peldaños; un valor que no caiga en
/// ninguno se redondea al más cercano, como en `PreferenceScale` (ADR-0021).
class ConversationSettings {
  const ConversationSettings({
    this.inactivityMinutes = defaultInactivityMinutes,
    this.retentionDays = defaultRetentionDays,
  });

  static const String inactivityMinutesKey = 'inactivityMinutes';
  static const String retentionDaysKey = 'retentionDays';

  static const int defaultInactivityMinutes = 5;
  static const int defaultRetentionDays = 90;

  static const List<int> inactivityMinutesSteps = [2, 5, 10, 15];
  static const List<String> inactivityMinutesLabels = [
    'Muy poco',
    'Normal',
    'Un rato',
    'Mucho rato',
  ];

  /// El servidor aplica el mismo tope (`closeConversation`,
  /// `setConversationConsent`): el cliente no es quien protege los datos.
  static const List<int> retentionDaysSteps = [30, 60, 90, 180];
  static const List<String> retentionDaysLabels = [
    'Un mes',
    'Dos meses',
    'Tres meses',
    'Seis meses',
  ];

  final int inactivityMinutes;
  final int retentionDays;

  Duration get inactivity => Duration(minutes: inactivityMinutes);

  /// Tras retirar el consentimiento, lo guardado se borra pasada la mitad del
  /// plazo de conservación (ADR-0030, epílogo).
  int get gracePeriodDays => retentionDays ~/ 2;

  String get inactivityLabel => inactivityMinutesLabels[inactivityMinutesSteps
      .indexOf(_nearest(inactivityMinutesSteps, inactivityMinutes))];

  String get retentionLabel => retentionDaysLabels[
      retentionDaysSteps.indexOf(_nearest(retentionDaysSteps, retentionDays))];

  /// El plazo en una frase para el mayor: "tres meses".
  String get retentionPhrase => retentionLabel.toLowerCase();

  ConversationSettings copyWith({int? inactivityMinutes, int? retentionDays}) {
    return ConversationSettings(
      inactivityMinutes:
          _nearest(inactivityMinutesSteps, inactivityMinutes ?? this.inactivityMinutes),
      retentionDays: _nearest(retentionDaysSteps, retentionDays ?? this.retentionDays),
    );
  }

  Map<String, dynamic> toMap() => {
        inactivityMinutesKey: inactivityMinutes,
        retentionDaysKey: retentionDays,
      };

  /// null es un estado legal: documento anterior a esta función, o mayor que
  /// nunca los ha tocado. Quien lee usa entonces los valores por defecto.
  static ConversationSettings? fromMapOrNull(Object? raw) {
    if (raw is! Map) return null;
    final inactivity = raw[inactivityMinutesKey];
    final retention = raw[retentionDaysKey];
    return ConversationSettings(
      inactivityMinutes: _nearest(
        inactivityMinutesSteps,
        inactivity is num ? inactivity.round() : defaultInactivityMinutes,
      ),
      retentionDays: _nearest(
        retentionDaysSteps,
        retention is num ? retention.round() : defaultRetentionDays,
      ),
    );
  }

  /// Peldaño más cercano; en empate, el más bajo (lo más conservador).
  static int _nearest(List<int> steps, int value) {
    var best = steps.first;
    for (final step in steps) {
      if ((step - value).abs() < (best - value).abs()) best = step;
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is ConversationSettings &&
      other.inactivityMinutes == inactivityMinutes &&
      other.retentionDays == retentionDays;

  @override
  int get hashCode => Object.hash(inactivityMinutes, retentionDays);
}
