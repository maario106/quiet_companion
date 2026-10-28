import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';
import 'package:quiet_companion/features/my_week/domain/my_week_text.dart';

final _now = DateTime(2026, 9, 26, 20);

WeekSummary _week({
  List<ConversationRecord> records = const [],
  Map<String, ConversationContent> contents = const {},
}) =>
    summarizeWeek(records: records, contents: contents, now: _now);

ConversationRecord _record(String id, DateTime at,
        {Sentiment sentiment = Sentiment.positive,
        List<ConversationSignal> signals = const []}) =>
    ConversationRecord(
      id: id,
      startedAt: at.subtract(const Duration(minutes: 5)),
      endedAt: at,
      sentiment: sentiment,
      signals: signals,
    );

void main() {
  test('semana sin conversaciones: una invitación, sin reproches', () {
    final text = myWeekSentences(_week(), _now);
    expect(text.single, contains('todavía no hemos hablado'));
  });

  test('nunca nombra las señales clínicas', () {
    final text = myWeekSentences(
      _week(records: [
        _record('a', DateTime(2026, 9, 26),
            sentiment: Sentiment.negative,
            signals: [ConversationSignal.loneliness, ConversationSignal.risk]),
      ]),
      _now,
    ).join(' ').toLowerCase();

    expect(text, isNot(contains('soledad')));
    expect(text, isNot(contains('sola')));
    expect(text, isNot(contains('daño')));
    expect(text, contains('más difíciles'));
  });
}
