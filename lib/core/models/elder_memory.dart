import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Un resumen reciente, para retomar lo hablado en la conversación siguiente.
class RecentSummary {
  const RecentSummary({required this.endedAt, required this.summary});

  final DateTime endedAt;
  final String summary;
}

/// `users/{elderId}/memory/profile`: lo que el asistente recuerda del mayor
/// (ADR-0032). Lo escribe solo `closeConversation` y lo inyecta en el modelo
/// `chatTurn`; aquí solo lo lee el panel del familiar.
class ElderMemory {
  const ElderMemory({this.facts = const {}, this.recent = const []});

  /// Datos estables: "nieto" → "Pablo, 8 años".
  final Map<String, String> facts;

  /// Las últimas conversaciones analizadas, de la más reciente a la más vieja.
  final List<RecentSummary> recent;

  bool get isEmpty => facts.isEmpty && recent.isEmpty;

  static ElderMemory? fromMapOrNull(Map<String, dynamic>? map) {
    if (map == null) return null;
    final rawFacts = map['facts'];
    final rawRecent = map['recent'];
    return ElderMemory(
      facts: {
        if (rawFacts is Map)
          for (final entry in rawFacts.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
      recent: [
        if (rawRecent is List)
          for (final item in rawRecent)
            if (item is Map &&
                item['endedAt'] is Timestamp &&
                item['summary'] is String)
              RecentSummary(
                endedAt: (item['endedAt'] as Timestamp).toDate(),
                summary: item['summary'] as String,
              ),
      ],
    );
  }
}
