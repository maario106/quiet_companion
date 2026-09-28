import 'package:quiet_companion/core/models/conversation_record.dart';

/// Un día de la semana, con lo que se habló.
class DaySummary {
  const DaySummary({
    required this.day,
    required this.conversations,
    required this.talkTime,
    this.mood,
  });

  /// Medianoche local del día.
  final DateTime day;
  final int conversations;
  final Duration talkTime;

  /// Ánimo predominante del día entre las conversaciones analizadas.
  final Sentiment? mood;
}

/// Lo que el panel y "Mi semana" cuentan de los últimos siete días.
///
/// Una sola función para los dos (ADR-0033): si cada pantalla calculara por su
/// cuenta, el mayor y su familiar acabarían viendo números distintos.
class WeekSummary {
  const WeekSummary({
    required this.days,
    required this.lastConversationAt,
    required this.mood,
    required this.signalCounts,
    required this.topTopics,
    required this.worryTopics,
    required this.analyzedCount,
  });

  /// Siete días, del más antiguo a hoy.
  final List<DaySummary> days;

  /// La conversación más reciente de toda la ventana, no solo de la semana:
  /// que el mayor deje de hablar es en sí una señal.
  final DateTime? lastConversationAt;

  /// Ánimo predominante de la semana; null sin conversaciones analizadas.
  final Sentiment? mood;

  /// En cuántas conversaciones de la semana apareció cada señal.
  final Map<ConversationSignal, int> signalCounts;

  /// Temas más repetidos de la semana (como mucho 5).
  final List<String> topTopics;

  /// Temas de las conversaciones con la señal `worry`: "lo que le ha rondado
  /// la cabeza" (como mucho 3).
  final List<String> worryTopics;

  final int analyzedCount;

  int get daysWithConversation => days.where((d) => d.conversations > 0).length;
  int get conversationCount => days.fold(0, (n, d) => n + d.conversations);
  Duration get talkTime =>
      days.fold(Duration.zero, (total, d) => total + d.talkTime);
}

/// Resume los últimos siete días (hoy incluido) a partir de [records] y, si el
/// nivel lo permite, [contents].
WeekSummary summarizeWeek({
  required List<ConversationRecord> records,
  Map<String, ConversationContent> contents = const {},
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final firstDay = today.subtract(const Duration(days: 6));
  final week = records.where((r) => !r.endedAt.isBefore(firstDay)).toList();

  final days = <DaySummary>[
    for (var i = 0; i < 7; i++)
      _summarizeDay(
        DateTime(firstDay.year, firstDay.month, firstDay.day + i),
        week,
      ),
  ];

  final analyzed = week.where((r) => r.isAnalyzed).toList();

  final signalCounts = <ConversationSignal, int>{};
  for (final record in analyzed) {
    for (final signal in record.signals.toSet()) {
      signalCounts[signal] = (signalCounts[signal] ?? 0) + 1;
    }
  }

  DateTime? last;
  for (final record in records) {
    if (last == null || record.endedAt.isAfter(last)) last = record.endedAt;
  }

  final weekContents = [
    for (final record in week)
      if (contents[record.id] case final content?) (record, content),
  ];

  return WeekSummary(
    days: days,
    lastConversationAt: last,
    mood: predominantSentiment(analyzed.map((r) => r.sentiment)),
    signalCounts: signalCounts,
    topTopics: _topTopics(weekContents.map((pair) => pair.$2), 5),
    worryTopics: _topTopics(
      weekContents
          .where((pair) => pair.$1.signals.contains(ConversationSignal.worry))
          .map((pair) => pair.$2),
      3,
    ),
    analyzedCount: analyzed.length,
  );
}

DaySummary _summarizeDay(DateTime day, List<ConversationRecord> week) {
  final next = DateTime(day.year, day.month, day.day + 1);
  final ofDay = week
      .where((r) => !r.endedAt.isBefore(day) && r.endedAt.isBefore(next))
      .toList();
  return DaySummary(
    day: day,
    conversations: ofDay.length,
    talkTime: ofDay.fold(Duration.zero, (total, r) => total + r.duration),
    mood: predominantSentiment(
        ofDay.where((r) => r.isAnalyzed).map((r) => r.sentiment)),
  );
}

/// El ánimo más repetido. En empate, neutro: ante la duda no se afirma ni que
/// estuvo bien ni que estuvo mal.
Sentiment? predominantSentiment(Iterable<Sentiment?> sentiments) {
  final counts = <Sentiment, int>{};
  for (final s in sentiments) {
    if (s != null) counts[s] = (counts[s] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final best = counts.values.reduce((a, b) => a > b ? a : b);
  final leaders = counts.keys.where((s) => counts[s] == best).toList();
  return leaders.length == 1 ? leaders.single : Sentiment.neutral;
}

/// Temas por frecuencia; en empate, el orden de aparición (más reciente
/// primero, porque los registros llegan así).
List<String> _topTopics(Iterable<ConversationContent> contents, int max) {
  final counts = <String, int>{};
  for (final content in contents) {
    for (final topic in content.topics.toSet()) {
      counts[topic] = (counts[topic] ?? 0) + 1;
    }
  }
  final ordered = counts.keys.toList();
  // Ordenación estable: conserva el orden de aparición en los empates.
  final indexed = {for (var i = 0; i < ordered.length; i++) ordered[i]: i};
  ordered.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0 ? byCount : indexed[a]!.compareTo(indexed[b]!);
  });
  return ordered.take(max).toList();
}
