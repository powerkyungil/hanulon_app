import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_time_parser.dart';

void main() {
  group('BossTimeParser', () {
    test('원본 4자리 입력을 MMSS로 해석한다', () {
      expect(
        BossTimeParser.parseRemaining('2410'),
        const Duration(minutes: 24, seconds: 10),
      );
    });

    test('원본 6자리 입력을 HHMMSS로 해석한다', () {
      expect(
        BossTimeParser.parseRemaining('013020'),
        const Duration(hours: 1, minutes: 30, seconds: 20),
      );
    });

    test('한글 단위 조합을 해석한다', () {
      expect(
        BossTimeParser.parseRemaining('1시간 5분 7초'),
        const Duration(hours: 1, minutes: 5, seconds: 7),
      );
    });

    test('올바르지 않은 시간은 거부한다', () {
      expect(BossTimeParser.parseRemaining('곧 등장'), isNull);
      expect(BossTimeParser.parseClock('25:00:00'), isNull);
    });
  });
}
