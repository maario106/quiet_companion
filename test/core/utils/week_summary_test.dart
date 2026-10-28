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
  });

  group('predominantSentiment', () {
    test('en empate, neutro: no se afirma ni bien ni mal', () {
      expect(
        predominantSentiment([Sentiment.positive, Sentiment.negative]),
        Sentiment.neutral,
      );
    });
  });
}
