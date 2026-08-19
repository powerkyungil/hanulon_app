import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_definition.dart';
import 'package:odin_guild_app/features/schedule/domain/fixed_schedule_builder.dart';

void main() {
  test('고정 일정은 서울 기준 오늘과 내일의 설정 요일에 생성한다', () {
    final now = DateTime.utc(2026, 8, 11, 3).millisecondsSinceEpoch;
    final schedules = FixedScheduleBuilder.build(
      definitions: const <BossDefinition>[
        BossDefinition(
          id: 1,
          type: '고정',
          region: '공통',
          boss: '고정 보스',
          cooldownHours: 0,
          timeText: '21:30:00',
          days: <String>['화', '수'],
        ),
      ],
      nowMilliseconds: now,
    );

    expect(schedules, hasLength(2));
    expect(schedules.every((item) => item.isFixed), isTrue);
    expect(
      schedules.first.spawnTime,
      DateTime.utc(2026, 8, 11, 12, 30).millisecondsSinceEpoch,
    );
    expect(
      schedules.last.spawnTime,
      DateTime.utc(2026, 8, 12, 12, 30).millisecondsSinceEpoch,
    );
  });

  test('30분보다 오래 지난 고정 일정은 목록에 다시 주입하지 않는다', () {
    final now = DateTime.utc(2026, 8, 11, 13, 1).millisecondsSinceEpoch;
    final schedules = FixedScheduleBuilder.build(
      definitions: const <BossDefinition>[
        BossDefinition(
          id: 1,
          type: '고정',
          region: '공통',
          boss: '지난 고정 보스',
          cooldownHours: 0,
          timeText: '21:30:00',
          days: <String>['화'],
        ),
      ],
      nowMilliseconds: now,
    );

    expect(schedules, isEmpty);
  });
}
