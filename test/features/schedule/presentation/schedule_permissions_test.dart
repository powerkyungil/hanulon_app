import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';
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
  _FakeScheduleRepository({List<BossDefinition>? definitions})
    : definitions =
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
  final List<BossSchedule> createdSchedules = <BossSchedule>[];

  static final _now = _FixedServerClock._now.millisecondsSinceEpoch;

  @override
  Future<ScheduleOverview> fetchOverview() async {
    return ScheduleOverview(
      schedules: <BossSchedule>[
        BossSchedule(
          id: 1,
          bossDefinitionId: 1,
          type: '본섭',
          region: '요툰하임',
          boss: '파르바',
          spawnTime: _now - const Duration(minutes: 10).inMilliseconds,
          isMung: false,
        ),
      ],
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
