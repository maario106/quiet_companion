class UserPreferences {
  final double volume; // 0.0 a 1.0
  final double speechRate; // Velocidad de voz: 0.0 a 1.0 (suele ser mejor lenta)
  final double textSizeMultiplier; // Multiplicador para hacer la letra más grande (1.0, 1.2, 1.5...)

  /// Segundos de silencio tras los que se da por terminado lo que dice el
  /// mayor y se le contesta (ADR-0036). Era una constante de 2 s (ADR-0022), y
  /// en las primeras pruebas cortaba a media idea: cuánto se para alguien a
  /// pensar depende de la persona, así que lo elige ella.
  final double listenPauseSeconds;

  /// Claves del mapa `preferences` en Firestore. Públicas porque el panel del
  /// familiar escribe cada magnitud por separado (`preferences.volume`) y
  /// necesita el mismo nombre que usan [toMap] y [fromMap].
  static const String volumeKey = 'volume';
  static const String speechRateKey = 'speechRate';
  static const String textSizeMultiplierKey = 'textSizeMultiplier';
  static const String listenPauseSecondsKey = 'listenPauseSeconds';

  /// Más que los 2 s de ADR-0022, que se quedaron cortos en dispositivo.
  static const double defaultListenPauseSeconds = 3.0;

  const UserPreferences({
    this.volume = 1.0, // Volumen al máximo por defecto
    this.speechRate = 0.4, // Voz un poco más lenta de lo normal para mayor claridad
    this.textSizeMultiplier = 1.2, // Texto ligeramente ampliado de base
    this.listenPauseSeconds = defaultListenPauseSeconds,
  });

  Duration get listenPause =>
      Duration(milliseconds: (listenPauseSeconds * 1000).round());

  UserPreferences copyWith({
    double? volume,
    double? speechRate,
    double? textSizeMultiplier,
    double? listenPauseSeconds,
  }) {
    return UserPreferences(
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      textSizeMultiplier: textSizeMultiplier ?? this.textSizeMultiplier,
      listenPauseSeconds: listenPauseSeconds ?? this.listenPauseSeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      volumeKey: volume,
      speechRateKey: speechRate,
      textSizeMultiplierKey: textSizeMultiplier,
      listenPauseSecondsKey: listenPauseSeconds,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      volume: map[volumeKey]?.toDouble() ?? 1.0,
      speechRate: map[speechRateKey]?.toDouble() ?? 0.4,
      textSizeMultiplier: map[textSizeMultiplierKey]?.toDouble() ?? 1.2,
      listenPauseSeconds: map[listenPauseSecondsKey]?.toDouble() ??
          defaultListenPauseSeconds,
    );
  }
}
