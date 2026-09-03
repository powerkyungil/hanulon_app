import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';
import 'package:odin_guild_app/core/widgets/app_hero_card.dart';
import 'package:odin_guild_app/core/widgets/status_tag.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/schedule/data/schedule_repository.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_definition.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_schedule.dart';
import 'package:odin_guild_app/features/schedule/domain/ocr_result.dart';
import 'package:odin_guild_app/features/schedule/domain/schedule_overview.dart';
import 'package:odin_guild_app/features/schedule/presentation/schedule_create_screen.dart';
import 'package:odin_guild_app/features/schedule/presentation/schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('일반 길드원에게 일정 등록·컷·멍·개별 삭제를 표시한다', (tester) async {
    await tester.pumpWidget(_buildApp(const ScheduleScreen()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('보스 시간 입력'), findsOneWidget);
    expect(find.text('컷'), findsOneWidget);
    expect(find.text('멍'), findsOneWidget);
    expect(find.byTooltip('삭제'), findsOneWidget);
    expect(find.byTooltip('일정 관리'), findsNothing);
  });

  testWidgets('다음 일정은 NEXT로 강조하고 진입 시 해당 위치로 이동한다', (tester) async {
    final repository = _FakeScheduleRepository(includeFuture: true);
    await tester.pumpWidget(
      _buildApp(const ScheduleScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEXT'), findsOneWidget);
    final verticalScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(verticalScrollable);
    expect(scrollableState.position.pixels, greaterThan(0));
  });

  testWidgets('NEXT 아이콘은 가장 왼쪽에 두고 유형 배지와 색상을 유지한다', (tester) async {
    final repository = _FakeScheduleRepository(includeFuture: true);
    await tester.pumpWidget(
      _buildApp(const ScheduleScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    final now = _FixedServerClock._now.millisecondsSinceEpoch;
    final regularVoteKey =
        '본섭|요툰하임|파르바|${now - const Duration(minutes: 10).inMilliseconds}';
    final nextVoteKey =
        '침공|니플하임|다음 보스|${now + const Duration(minutes: 10).inMilliseconds}';
    final followingVoteKey =
        '침공|니플하임|그 다음 보스|${now + const Duration(minutes: 20).inMilliseconds}';

    final regularBadge = tester.getRect(
      find.byKey(ValueKey<String>('schedule-type-$regularVoteKey')),
    );
    final regularBoss = tester.getRect(
      find.byKey(ValueKey<String>('schedule-boss-$regularVoteKey')),
    );
    expect(regularBadge.left, closeTo(regularBoss.left, 0.1));

    final nextIcon = tester.getRect(
      find.byKey(ValueKey<String>('schedule-next-icon-$nextVoteKey')),
    );
    final nextBadgeRect = tester.getRect(
      find.byKey(ValueKey<String>('schedule-type-$nextVoteKey')),
    );
    final nextBoss = tester.getRect(
      find.byKey(ValueKey<String>('schedule-boss-$nextVoteKey')),
    );
    expect(nextIcon.left, closeTo(nextBoss.left, 0.1));
    expect(nextBadgeRect.left, greaterThan(nextIcon.right));

    final heroCard = tester.getRect(find.byType(AppHeroCard));
    final nextLabel = tester.getRect(find.text('NEXT'));
    expect(nextLabel.center.dx, greaterThan(heroCard.center.dx));

    final nextBadge = tester.widget<StatusTag>(
      find.byKey(ValueKey<String>('schedule-type-$nextVoteKey')),
    );
    final followingBadge = tester.widget<StatusTag>(
      find.byKey(ValueKey<String>('schedule-type-$followingVoteKey')),
    );
    expect(nextBadge.foregroundColor, followingBadge.foregroundColor);
    expect(nextBadge.backgroundColor, followingBadge.backgroundColor);
  });

  testWidgets('일반 길드원의 일정 입력 화면에서 운영 설정은 숨긴다', (tester) async {
    await tester.pumpWidget(_buildApp(const ScheduleCreateScreen()));
    await tester.pumpAndSettle();

    expect(find.text('직접 입력'), findsOneWidget);
    expect(find.text('입력한 일정 전체 적용'), findsOneWidget);
    expect(find.byTooltip('보스 관리'), findsNothing);
    expect(find.text('참여 보스 설정'), findsNothing);
  });

  testWidgets('본섭 보스만 적용하면 본섭 입력값을 비운다', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeScheduleRepository(
      definitions: const <BossDefinition>[
        BossDefinition(
          id: 1,
          type: '공통',
          region: '요툰하임',
          boss: '파르바',
          cooldownHours: 12,
        ),
        BossDefinition(
          id: 2,
          type: '본섭',
          region: '요툰하임',
          boss: '파르바',
          cooldownHours: 12,
        ),
      ],
    );
    await tester.pumpWidget(
      _buildApp(const ScheduleCreateScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    final regionTiles = find.byType(ExpansionTile);
    expect(regionTiles, findsNWidgets(2));
    await tester.tap(regionTiles.at(1));
    await tester.pumpAndSettle();

    final bossFields = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '파르바',
    );
    final baseFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '기준 시각',
    );
    expect(bossFields, findsOneWidget);
    expect(baseFields, findsOneWidget);

    await tester.enterText(bossFields, '2410');
    final applyButton = find.text('이 지역만 적용');
    await tester.scrollUntilVisible(
      applyButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(bossFields).controller!.text, isEmpty);
    expect(tester.widget<TextField>(baseFields).controller!.text, isEmpty);
    expect(repository.createdSchedules.single.bossDefinitionId, 2);
  });
}

Widget _buildApp(Widget home, {ScheduleRepository? repository}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_MemberAuthController.new),
      scheduleRepositoryProvider.overrideWithValue(
        repository ?? _FakeScheduleRepository(),
      ),
      serverClockProvider.overrideWithValue(_FixedServerClock()),
    ],
    child: MaterialApp(theme: AppTheme.darkBlue, home: home),
  );
}

class _MemberAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'test-token',
      userId: 1,
      username: 'member',
      nickname: '길드원',
      role: UserRole.member,
    );
  }
}

class _FixedServerClock extends ServerClock {
  static final _now = DateTime.utc(2026, 8, 13, 12);

  @override
  DateTime now({DateTime? localNow}) => _now;
}

class _FakeScheduleRepository implements ScheduleRepository {
  _FakeScheduleRepository({
    List<BossDefinition>? definitions,
    this.includeFuture = false,
  }) : definitions =
           definitions ??
           const <BossDefinition>[
             BossDefinition(
               id: 1,
               type: '본섭',
               region: '요툰하임',
               boss: '파르바',
               cooldownHours: 12,
             ),
           ];

  final List<BossDefinition> definitions;
  final bool includeFuture;
  final List<BossSchedule> createdSchedules = <BossSchedule>[];

  static final _now = _FixedServerClock._now.millisecondsSinceEpoch;

  @override
  Future<ScheduleOverview> fetchOverview() async {
    final schedules = <BossSchedule>[
      BossSchedule(
        id: 1,
        bossDefinitionId: 1,
        type: '본섭',
        region: '요툰하임',
        boss: '파르바',
        spawnTime: _now - const Duration(minutes: 10).inMilliseconds,
        isMung: false,
      ),
    ];
    if (includeFuture) {
      schedules.addAll(<BossSchedule>[
        for (var index = 0; index < 4; index++)
          BossSchedule(
            id: index + 2,
            bossDefinitionId: index + 2,
            type: '공통',
            region: '던전',
            boss: '지난 보스 ${index + 1}',
            spawnTime:
                _now - const Duration(minutes: 20).inMilliseconds * (index + 1),
            isMung: false,
          ),
        BossSchedule(
          id: 10,
          bossDefinitionId: 10,
          type: '침공',
          region: '니플하임',
          boss: '다음 보스',
          spawnTime: _now + const Duration(minutes: 10).inMilliseconds,
          isMung: false,
        ),
        BossSchedule(
          id: 11,
          bossDefinitionId: 11,
          type: '침공',
          region: '니플하임',
          boss: '그 다음 보스',
          spawnTime: _now + const Duration(minutes: 20).inMilliseconds,
          isMung: false,
        ),
      ]);
    }
    return ScheduleOverview(
      schedules: schedules,
      participationTargetBossDefinitionIds: const <int>{},
      participantsByVoteKey: const <String, List<String>>{},
      closedVoteKeys: const <String>{},
      synchronizedAt: _FixedServerClock._now,
    );
  }

  @override
  Future<List<BossDefinition>> fetchBossDefinitions() async {
    return definitions;
  }

  @override
  Future<OcrAnalysis> analyzeScreenshot({
    required Uint8List bytes,
    required int templateId,
    required String contentType,
  }) async => const OcrAnalysis(fields: <OcrField>[]);

  @override
  Future<void> createBoss(BossDefinition definition) async {}

  @override
  Future<void> createSchedules(List<BossSchedule> schedules) async {
    createdSchedules.addAll(schedules);
  }

  @override
  Future<void> cut(BossSchedule schedule) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteBoss(int id) async {}

  @override
  Future<void> deleteSchedule(int id) async {}

  @override
  Future<List<OcrTemplate>> fetchOcrTemplates() async => const <OcrTemplate>[];

  @override
  Future<void> mung(BossSchedule schedule) async {}

  @override
  Future<void> reorderBosses(List<BossDefinition> definitions) async {}

  @override
  Future<void> resetBosses() async {}

  @override
  Future<void> saveParticipationTargets(Set<int> bossDefinitionIds) async {}

  @override
  Future<bool> toggleParticipation(BossSchedule schedule) async => true;
}
