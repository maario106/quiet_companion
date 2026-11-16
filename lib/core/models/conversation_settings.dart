/// Plazos de la conversación: inactividad que la cierra y conservación de lo
/// analizado. Los valores se redondean al peldaño más cercano.
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
    '2 minutos',
    '5 minutos',
    '10 minutos',
    '15 minutos',
  ];

  /// El servidor aplica el mismo tope.
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

  /// Días hasta el borrado tras retirar el consentimiento.
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

  /// null si el documento no tiene plazos; se usan los valores por defecto.
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

  /// Peldaño más cercano; en empate, el más bajo.
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
