import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';

final _now = DateTime(2026, 9, 26, 20); // sábado

ConversationRecord _record(
  String id,
  DateTime endedAt, {
  Sentiment? sentiment = Sentiment.neutral,
  List<ConversationSignal> signals = const [],
  ConversationStatus status = ConversationStatus.analyzed,
  Duration length = const Duration(minutes: 10),
}) {
  return ConversationRecord(
    id: id,
    startedAt: endedAt.subtract(length),
    endedAt: endedAt,
    status: status,
    sentiment: sentiment,
    signals: signals,
  );
}

void main() {
  group('summarizeWeek', () {
    test('semana vacía: siete días a cero y sin ánimo', () {
      final week = summarizeWeek(records: const [], now: _now);

      expect(week.days, hasLength(7));
      expect(week.daysWithConversation, 0);
      expect(week.mood, isNull);
      expect(week.lastConversationAt, isNull);
      expect(week.days.last.day, DateTime(2026, 9, 26));
      expect(week.days.first.day, DateTime(2026, 9, 20));
    });

    test('cuenta días, conversaciones y tiempo hablado', () {
      final week = summarizeWeek(records: [
        _record('a', DateTime(2026, 9, 26, 10)),
        _record('b', DateTime(2026, 9, 26, 18)),
        _record('c', DateTime(2026, 9, 24, 11), length: const Duration(minutes: 30)),
      ], now: _now);

      expect(week.daysWithConversation, 2);
      expect(week.conversationCount, 3);
      expect(week.talkTime, const Duration(minutes: 50));
      expect(week.days.last.conversations, 2);
    });

    test('lo anterior a la semana no cuenta, pero sí para la última vez', () {
      final old = DateTime(2026, 9, 10, 9);
      final week = summarizeWeek(records: [_record('a', old)], now: _now);

      expect(week.conversationCount, 0);
      expect(week.lastConversationAt, old);
    });

    test('las conversaciones sin analizar cuentan como actividad, no como ánimo',
        () {
      final week = summarizeWeek(records: [
        _record('a', DateTime(2026, 9, 26, 10),
            status: ConversationStatus.tooShort, sentiment: null),
      ], now: _now);

      expect(week.conversationCount, 1);
      expect(week.analyzedCount, 0);
      expect(week.mood, isNull);
    });

    test('señales: una por conversación, aunque se repita dentro', () {
      final week = summarizeWeek(records: [
        _record('a', DateTime(2026, 9, 25),
            signals: [ConversationSignal.loneliness, ConversationSignal.loneliness]),
        _record('b', DateTime(2026, 9, 26),
            signals: [ConversationSignal.loneliness, ConversationSignal.worry]),
      ], now: _now);

      expect(week.signalCounts[ConversationSignal.loneliness], 2);
      expect(week.signalCounts[ConversationSignal.worry], 1);
      expect(week.signalCounts[ConversationSignal.risk], isNull);
    });

    test('temas más repetidos y los de las conversaciones con preocupación', () {
      final records = [
        _record('a', DateTime(2026, 9, 26), signals: [ConversationSignal.worry]),
        _record('b', DateTime(2026, 9, 25)),
        _record('c', DateTime(2026, 9, 24)),
      ];
      final contents = {
        'a': ConversationContent(
            id: 'a', endedAt: DateTime(2026, 9, 26), topics: ['médico', 'familia']),
        'b': ConversationContent(
            id: 'b', endedAt: DateTime(2026, 9, 25), topics: ['familia', 'jardín']),
        'c': ConversationContent(
            id: 'c', endedAt: DateTime(2026, 9, 24), topics: ['familia']),
      };

      final week =
          summarizeWeek(records: records, contents: contents, now: _now);

      expect(week.topTopics.first, 'familia');
      expect(week.topTopics, containsAll(['médico', 'jardín']));
      expect(week.worryTopics, ['médico', 'familia']);
    });
  });

  group('predominantSentiment', () {
    test('el más repetido', () {
      expect(
        predominantSentiment([Sentiment.positive, Sentiment.positive, Sentiment.negative]),
        Sentiment.positive,
      );
    });

    test('en empate, neutro: no se afirma ni bien ni mal', () {
      expect(
        predominantSentiment([Sentiment.positive, Sentiment.negative]),
        Sentiment.neutral,
      );
    });

    test('sin datos, null', () {
      expect(predominantSentiment([null, null]), isNull);
    });
  });
}
