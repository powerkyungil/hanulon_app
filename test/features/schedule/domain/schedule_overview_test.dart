import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_schedule.dart';
import 'package:odin_guild_app/features/schedule/domain/schedule_overview.dart';

void main() {
  const schedule = BossSchedule(
    id: 1,
    bossDefinitionId: 11,
    type: '본섭',
    region: '요툰하임',
    boss: '파르바',
    spawnTime: 1000,
    isMung: false,
  );

  test('참여 대상 일정의 참여자를 vote key로 조회한다', () {
    final overview = ScheduleOverview(
      schedules: const <BossSchedule>[schedule],
      participationTargetBossDefinitionIds: const <int>{11},
      participantsByVoteKey: const <String, List<String>>{
        '본섭|요툰하임|파르바|1000': <String>['프레이야'],
      },
      closedVoteKeys: const <String>{},
      synchronizedAt: DateTime(2026),
    );

    expect(overview.canParticipate(schedule), isTrue);
    expect(overview.participantsFor(schedule), <String>['프레이야']);
  });

  test('마감된 일정은 참여할 수 없다', () {
    final overview = ScheduleOverview(
      schedules: const <BossSchedule>[schedule],
      participationTargetBossDefinitionIds: const <int>{11},
      participantsByVoteKey: const <String, List<String>>{},
      closedVoteKeys: const <String>{'본섭|요툰하임|파르바|1000'},
      synchronizedAt: DateTime(2026),
    );

    expect(overview.canParticipate(schedule), isFalse);
  });

  test('같은 이름의 본섭과 침공 보스를 독립적으로 참여 설정한다', () {
    const invasion = BossSchedule(
      id: 2,
      bossDefinitionId: 12,
      type: '침공',
      region: '니플하임',
      boss: '파르바',
      spawnTime: 2000,
      isMung: false,
    );
    final overview = ScheduleOverview(
      schedules: const <BossSchedule>[schedule, invasion],
      participationTargetBossDefinitionIds: const <int>{12},
      participantsByVoteKey: const <String, List<String>>{},
      closedVoteKeys: const <String>{},
      synchronizedAt: DateTime(2026),
    );

    expect(overview.isParticipationTarget(schedule), isFalse);
    expect(overview.isParticipationTarget(invasion), isTrue);
  });
}
