import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/boss_vote/data/boss_vote_repository.dart';
import 'package:odin_guild_app/features/boss_vote/domain/manual_vote_input.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_boss.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_participant.dart';
import 'package:odin_guild_app/features/boss_vote/presentation/boss_vote_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('운영진에게만 수동 투표 추가 진입점을 표시한다', (tester) async {
    await tester.pumpWidget(_buildApp(UserRole.admin));
    await tester.pumpAndSettle();

    expect(find.byTooltip('수동 투표 추가'), findsOneWidget);
    await tester.tap(find.byTooltip('수동 투표 추가'));
    await tester.pumpAndSettle();

    expect(find.text('수동 투표 추가'), findsOneWidget);
    expect(find.text('보스명'), findsOneWidget);
    expect(find.text('보스 유형'), findsOneWidget);
  });

  testWidgets('일반 길드원에게는 수동 투표 추가 진입점을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_buildApp(UserRole.member));
    await tester.pumpAndSettle();

    expect(find.byTooltip('수동 투표 추가'), findsNothing);
  });

  testWidgets('본섭과 침공 뱃지는 보스명 위 왼쪽에 고정한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = <VoteBoss>[
      _voteBoss(id: 1, type: '본섭', joined: true, isManual: true),
      _voteBoss(id: 2, type: '침공', isBlessed: true),
    ];
    await tester.pumpWidget(_buildApp(UserRole.member, items: items));
    await tester.pumpAndSettle();

    for (final item in items) {
      final badge = tester.getRect(
        find.byKey(ValueKey<String>('vote-type-${item.voteKey}')),
      );
      final boss = tester.getRect(
        find.byKey(ValueKey<String>('vote-boss-${item.voteKey}')),
      );

      expect(badge.left, closeTo(boss.left, 0.1));
      expect(badge.bottom, lessThan(boss.top));
    }
  });

  testWidgets('참여자 보기는 화면 비율에 맞는 그리드 시트로 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = _voteBoss(
      id: 1,
      type: '본섭',
      participants: const <VoteParticipant>[
        VoteParticipant(userId: 1, nickname: '길드원 하나'),
        VoteParticipant(userId: 2, nickname: '길드원 둘'),
        VoteParticipant(userId: 3, nickname: '길드원 셋'),
      ],
    );
    await tester.pumpWidget(
      _buildApp(UserRole.member, items: <VoteBoss>[item]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('참여자 보기'));
    await tester.pumpAndSettle();

    final sheet = tester.getSize(
      find.byKey(const ValueKey<String>('vote-participants-sheet')),
    );
    expect(sheet.width, closeTo(390, 0.1));
    expect(sheet.height, greaterThan(sheet.width));
    expect(find.text('파르바 참여자'), findsOneWidget);
    expect(find.text('총 3명'), findsOneWidget);
    for (final participant in item.participants) {
      expect(
        find.byKey(
          ValueKey<String>(
            'vote-participant-${item.voteKey}-${participant.userId}',
          ),
        ),
        findsOneWidget,
      );
    }
  });
}

Widget _buildApp(UserRole role, {List<VoteBoss> items = const <VoteBoss>[]}) {
  return ProviderScope(
    overrides: [
      bossVoteRepositoryProvider.overrideWithValue(
        _FakeBossVoteRepository(items),
      ),
      authControllerProvider.overrideWith(() => _FakeAuthController(role)),
      serverClockProvider.overrideWithValue(_FixedServerClock()),
    ],
    child: MaterialApp(theme: AppTheme.darkBlue, home: const BossVoteScreen()),
  );
}

VoteBoss _voteBoss({
  required int id,
  required String type,
  bool joined = false,
  bool isBlessed = false,
  bool isManual = false,
  List<VoteParticipant> participants = const <VoteParticipant>[],
}) {
  final spawnTime = DateTime.utc(2026, 8, 17, id).millisecondsSinceEpoch;
  return VoteBoss(
    id: id,
    voteKey: 'vote-$id',
    type: type,
    region: '공통',
    boss: id == 1 ? '파르바' : '브륀힐드',
    spawnTime: spawnTime,
    participants: participants,
    joined: joined,
    isClosed: false,
    isBlessed: isBlessed,
    isManual: isManual,
    isHistory: false,
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._role);

  final UserRole _role;

  @override
  Future<Session?> build() async {
    return Session(
      accessToken: 'test-token',
      userId: 1,
      username: 'tester',
      nickname: '테스터',
      role: _role,
    );
  }
}

class _FakeBossVoteRepository implements BossVoteRepository {
  _FakeBossVoteRepository(this.items);

  final List<VoteBoss> items;

  @override
  Future<List<VoteBoss>> fetchVoteBosses() async => items;

  @override
  Future<void> createManualVote(ManualVoteInput input) async {}

  @override
  Future<bool> toggleParticipation(VoteBoss voteBoss) async => true;
}

class _FixedServerClock extends ServerClock {
  @override
  DateTime now({DateTime? localNow}) => DateTime.utc(2026, 8, 17);
}
