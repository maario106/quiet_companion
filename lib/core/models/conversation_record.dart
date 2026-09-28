import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Ánimo del mayor en una conversación, en las tres clases de RF-8.
enum Sentiment {
  positive('Positivo'),
  neutral('Neutro'),
  negative('Negativo');

  const Sentiment(this.label);

  /// Etiqueta para el panel del familiar.
  final String label;

  static Sentiment? fromNameOrNull(Object? raw) =>
      raw is String ? Sentiment.values.asNameMap()[raw] : null;
}

/// Señales de lista cerrada que el análisis puede marcar (ADR-0029). Solo las
/// que el mayor expresa por sí mismo.
enum ConversationSignal {
  loneliness('loneliness', 'Soledad'),
  sadness('sadness', 'Tristeza'),
  worry('worry', 'Preocupación'),
  physicalDiscomfort('physical_discomfort', 'Molestias físicas'),
  confusion('confusion', 'Desorientación'),
  risk('risk', 'Ideas de hacerse daño');

  const ConversationSignal(this.wireName, this.label);

  /// Nombre en Firestore (lo escribe la Function).
  final String wireName;

  /// Etiqueta para el panel del familiar. Nunca se enseña al mayor tal cual
  /// (ADR-0033).
  final String label;

  static ConversationSignal? fromWireOrNull(Object? raw) {
    for (final signal in values) {
      if (signal.wireName == raw) return signal;
    }
    return null;
  }
}

/// Estado del análisis de una conversación.
enum ConversationStatus {
  analyzed,
  tooShort,
  failed;

  static ConversationStatus fromWire(Object? raw) => switch (raw) {
        'analyzed' => analyzed,
        'too_short' => tooShort,
        _ => failed,
      };
}

/// `users/{elderId}/conversations/{id}`: el nivel "cómo se encuentra"
/// (ADR-0031). Lo escribe solo `closeConversation`.
class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    this.elderTurns = 0,
    this.status = ConversationStatus.analyzed,
    this.sentiment,
    this.signals = const [],
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int elderTurns;
  final ConversationStatus status;
  final Sentiment? sentiment;
  final List<ConversationSignal> signals;

  Duration get duration => endedAt.difference(startedAt);

  bool get isAnalyzed => status == ConversationStatus.analyzed;

  /// null si el documento no tiene las fechas: no se puede situar en el tiempo.
  static ConversationRecord? fromMapOrNull(String id, Map<String, dynamic> map) {
    final startedAt = _date(map['startedAt']);
    final endedAt = _date(map['endedAt']);
    if (startedAt == null || endedAt == null) return null;
    final turns = map['elderTurns'];
    final rawSignals = map['signals'];
    return ConversationRecord(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      elderTurns: turns is num ? turns.toInt() : 0,
      status: ConversationStatus.fromWire(map['status']),
      sentiment: Sentiment.fromNameOrNull(map['sentiment']),
      signals: [
        if (rawSignals is List)
          for (final raw in rawSignals)
            if (ConversationSignal.fromWireOrNull(raw) case final signal?)
              signal,
      ],
    );
  }
}

/// `users/{elderId}/conversationContents/{id}`: el nivel "de qué habláis"
/// (ADR-0031). Mismo id que su [ConversationRecord].
class ConversationContent {
  const ConversationContent({
    required this.id,
    required this.endedAt,
    this.topics = const [],
    this.summary = '',
  });

  final String id;
  final DateTime endedAt;
  final List<String> topics;
  final String summary;

  static ConversationContent? fromMapOrNull(
      String id, Map<String, dynamic> map) {
    final endedAt = _date(map['endedAt']);
    if (endedAt == null) return null;
    final topics = map['topics'];
    final summary = map['summary'];
    return ConversationContent(
      id: id,
      endedAt: endedAt,
      topics: [
        if (topics is List)
          for (final topic in topics)
            if (topic is String) topic,
      ],
      summary: summary is String ? summary : '',
    );
  }
}

DateTime? _date(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}
