class UserPreferences {
  final double volume; // 0.0 a 1.0
  final double speechRate; // Velocidad de voz: 0.0 a 1.0 (suele ser mejor lenta)
  final double textSizeMultiplier; // Multiplicador para hacer la letra más grande (1.0, 1.2, 1.5...)

  const UserPreferences({
    this.volume = 1.0, // Volumen al máximo por defecto
    this.speechRate = 0.4, // Voz un poco más lenta de lo normal para mayor claridad
    this.textSizeMultiplier = 1.2, // Texto ligeramente ampliado de base
  });

  UserPreferences copyWith({
    double? volume,
    double? speechRate,
    double? textSizeMultiplier,
  }) {
    return UserPreferences(
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      textSizeMultiplier: textSizeMultiplier ?? this.textSizeMultiplier,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'volume': volume,
      'speechRate': speechRate,
      'textSizeMultiplier': textSizeMultiplier,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      volume: map['volume']?.toDouble() ?? 1.0,
      speechRate: map['speechRate']?.toDouble() ?? 0.4,
      textSizeMultiplier: map['textSizeMultiplier']?.toDouble() ?? 1.2,
    );
  }
}