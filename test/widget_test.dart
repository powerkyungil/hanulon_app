import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/boss_vote/data/boss_vote_repository.dart';
import 'package:odin_guild_app/features/boss_vote/domain/manual_vote_input.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_boss.dart';
import 'package:odin_guild_app/features/home/presentation/home_screen.dart';
import 'package:odin_guild_app/features/notice/data/notice_repository.dart';
import 'package:odin_guild_app/features/notice/domain/notice_article.dart';
import 'package:odin_guild_app/features/notice/domain/notice_overview.dart';
import 'package:odin_guild_app/features/schedule/data/schedule_repository.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_definition.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_schedule.dart';
import 'package:odin_guild_app/features/schedule/domain/ocr_result.dart';
import 'package:odin_guild_app/features/schedule/domain/schedule_overview.dart';
import 'package:odin_guild_app/features/settings/data/settings_repository.dart';
import 'package:odin_guild_app/features/settings/domain/guild_invite.dart';
import 'package:odin_guild_app/features/settings/domain/guild_settings.dart';

void main() {
  testWidgets('홈 화면은 핵심 길드 정보를 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            _FakeScheduleRepository(),
          ),
          bossVoteRepositoryProvider.overrideWithValue(
            _FakeBossVoteRepository(),
          ),
          noticeRepositoryProvider.overrideWithValue(_FakeNoticeRepository()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('다음 보스'), findsOneWidget);
    expect(find.text('예정된 일정이 없어요'), findsOneWidget);
    expect(find.text('오늘의 길드'), findsOneWidget);
    expect(find.text('아스가르드'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();

    expect(find.text('공지사항'), findsOneWidget);
  });
}

class _FakeScheduleRepository implements ScheduleRepository {
  @override
  Future<OcrAnalysis> analyzeScreenshot({
    required Uint8List bytes,
    required int templateId,
    required String contentType,
  }) async => const OcrAnalysis(fields: <OcrField>[]);

  @override
  Future<void> createBoss(BossDefinition definition) async {}

  @override
  Future<ScheduleOverview> fetchOverview() async {
    return ScheduleOverview(
      schedules: const <BossSchedule>[],
      participationTargetBossDefinitionIds: const <int>{},
      participantsByVoteKey: const <String, List<String>>{},
      closedVoteKeys: const <String>{},
      synchronizedAt: DateTime(2026),
    );
  }

  @override
  Future<List<BossDefinition>> fetchBossDefinitions() async =>
      const <BossDefinition>[];

  @override
  Future<void> createSchedules(List<BossSchedule> schedules) async {}

  @override
  Future<void> cut(BossSchedule schedule) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteBoss(int id) async {}

  @override
  Future<void> deleteSchedule(int id) async {}

  @override
  Future<void> mung(BossSchedule schedule) async {}

  @override
  Future<List<OcrTemplate>> fetchOcrTemplates() async => const <OcrTemplate>[];

  @override
  Future<void> resetBosses() async {}

  @override
  Future<void> reorderBosses(List<BossDefinition> definitions) async {}

  @override
  Future<void> saveParticipationTargets(Set<int> bossDefinitionIds) async {}

  @override
  Future<bool> toggleParticipation(BossSchedule schedule) async => true;
}

class _FakeBossVoteRepository implements BossVoteRepository {
  @override
  Future<List<VoteBoss>> fetchVoteBosses() async => const <VoteBoss>[];

  @override
  Future<void> createManualVote(ManualVoteInput input) async {}

  @override
  Future<bool> toggleParticipation(VoteBoss voteBoss) async => true;
}

class _FakeNoticeRepository implements NoticeRepository {
  @override
  Future<NoticeOverview> fetchOverview() async {
    return const NoticeOverview(rules: [], priceGuides: [], bossControls: []);
  }

  @override
  Future<void> createArticle(
    NoticeArticleType type,
    NoticeArticleInput input,
  ) async {}

  @override
  Future<void> deleteArticle(NoticeArticleType type, int id) async {}

  @override
  Future<void> reorderRules(List<int> ids) async {}

  @override
  Future<void> updateArticle(
    NoticeArticleType type,
    int id,
    NoticeArticleInput input,
  ) async {}

  @override
  Future<void> updateBossControl({
    required String chapter,
    required String boss,
    required String status,
  }) async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<GuildSettings> fetchSettings() async {
    return const GuildSettings(
      guildName: '아스가르드',
      allowMemberCombatPowerEdit: true,
    );
  }

  @override
  Future<List<GuildInvite>> fetchInvites() async {
    return const <GuildInvite>[
      GuildInvite(code: 'TEST-CODE', role: UserRole.member),
    ];
  }

  @override
  Future<void> saveSettings(GuildSettings settings) async {}

  @override
  Future<GuildInvite> createInvite(
    UserRole role, {
    String customCode = '',
  }) async {
    return GuildInvite(
      code: customCode.isEmpty ? 'TEST-CODE' : customCode,
      role: role,
    );
  }
}
