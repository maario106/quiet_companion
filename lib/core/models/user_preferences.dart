class UserPreferences {
  final double volume; // 0.0 a 1.0
  final double speechRate; // 0.0 a 1.0
  final double textSizeMultiplier;

  /// Silencio, en segundos, tras el que se da por terminado lo que dice el mayor.
  final double listenPauseSeconds;

  /// Clave de la voz de nube elegida (tts_voices.dart).
  final String voice;

  /// Claves del mapa preferences; el panel del familiar escribe cada una por separado.
  static const String volumeKey = 'volume';
  static const String speechRateKey = 'speechRate';
  static const String textSizeMultiplierKey = 'textSizeMultiplier';
  static const String listenPauseSecondsKey = 'listenPauseSeconds';
  static const String voiceKey = 'voice';

  static const double defaultListenPauseSeconds = 3.0;

  /// La misma que `DEFAULT_VOICE` en `functions/index.js`.
  static const String defaultVoice = 'achird';

  const UserPreferences({
    this.volume = 1.0,
    this.speechRate = 0.4,
    this.textSizeMultiplier = 1.2,
    this.listenPauseSeconds = defaultListenPauseSeconds,
    this.voice = defaultVoice,
  });

  Duration get listenPause =>
      Duration(milliseconds: (listenPauseSeconds * 1000).round());

  UserPreferences copyWith({
    double? volume,
    double? speechRate,
    double? textSizeMultiplier,
    double? listenPauseSeconds,
    String? voice,
  }) {
    return UserPreferences(
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      textSizeMultiplier: textSizeMultiplier ?? this.textSizeMultiplier,
      listenPauseSeconds: listenPauseSeconds ?? this.listenPauseSeconds,
      voice: voice ?? this.voice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      volumeKey: volume,
      speechRateKey: speechRate,
      textSizeMultiplierKey: textSizeMultiplier,
      listenPauseSecondsKey: listenPauseSeconds,
      voiceKey: voice,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    final voice = map[voiceKey];
    return UserPreferences(
      volume: map[volumeKey]?.toDouble() ?? 1.0,
      speechRate: map[speechRateKey]?.toDouble() ?? 0.4,
      textSizeMultiplier: map[textSizeMultiplierKey]?.toDouble() ?? 1.2,
      listenPauseSeconds: map[listenPauseSecondsKey]?.toDouble() ??
          defaultListenPauseSeconds,
      // Documentos sin clave de voz.
      voice: voice is String ? voice : defaultVoice,
    );
  }
}
