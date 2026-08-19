import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/time/seoul_datetime.dart';

void main() {
  test('서울 시각을 올바른 epoch milliseconds로 변환한다', () {
    final milliseconds = SeoulDateTime.toEpochMilliseconds(
      date: DateTime(2026, 8, 10),
      time: const TimeParts(hour: 21, minute: 30),
    );

    expect(
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
      DateTime.utc(2026, 8, 10, 12, 30),
    );
  });
}
