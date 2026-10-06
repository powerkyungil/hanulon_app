import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/core/widgets/app_background.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';
import 'package:odin_guild_app/features/auth/data/auth_repository.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/profile_settings.dart';
import 'package:odin_guild_app/features/auth/domain/profile_update_request.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_profile.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/auth/presentation/login_screen.dart';
import 'package:odin_guild_app/features/auth/presentation/profile_screen.dart';
import 'package:odin_guild_app/features/boss_vote/data/boss_vote_repository.dart';
import 'package:odin_guild_app/features/boss_vote/domain/manual_vote_input.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_boss.dart';
import 'package:odin_guild_app/features/collections/data/collection_repository.dart';
import 'package:odin_guild_app/features/collections/domain/collection_overview.dart';
import 'package:odin_guild_app/features/collections/domain/item_collection.dart';
import 'package:odin_guild_app/features/collections/presentation/collections_screen.dart';
import 'package:odin_guild_app/features/content_groups/data/content_group_repository.dart';
import 'package:odin_guild_app/features/content_groups/domain/content_group.dart';
import 'package:odin_guild_app/features/content_groups/presentation/content_groups_screen.dart';
import 'package:odin_guild_app/features/home/presentation/home_screen.dart';
import 'package:odin_guild_app/features/members/data/member_repository.dart';
import 'package:odin_guild_app/features/members/domain/guild_member.dart';
import 'package:odin_guild_app/features/members/domain/member_equipment.dart';
import 'package:odin_guild_app/features/members/presentation/member_detail_screen.dart';
import 'package:odin_guild_app/features/members/presentation/members_screen.dart';
import 'package:odin_guild_app/features/notice/data/notice_repository.dart';
import 'package:odin_guild_app/features/notice/domain/boss_control_chapter.dart';
import 'package:odin_guild_app/features/notice/domain/notice_article.dart';
import 'package:odin_guild_app/features/notice/domain/notice_overview.dart';
import 'package:odin_guild_app/features/notice/presentation/notice_screen.dart';
import 'package:odin_guild_app/features/schedule/data/schedule_repository.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_definition.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_schedule.dart';
import 'package:odin_guild_app/features/schedule/domain/ocr_result.dart';
import 'package:odin_guild_app/features/schedule/domain/schedule_overview.dart';
import 'package:odin_guild_app/features/schedule/presentation/schedule_screen.dart';
import 'package:odin_guild_app/features/schedule/presentation/schedule_create_screen.dart';
import 'package:odin_guild_app/features/settings/data/settings_repository.dart';
import 'package:odin_guild_app/features/settings/domain/guild_invite.dart';
import 'package:odin_guild_app/features/settings/domain/guild_settings.dart';
import 'package:odin_guild_app/features/settings/presentation/master_settings_screen.dart';
import 'package:odin_guild_app/features/siege/data/siege_repository.dart';
import 'package:odin_guild_app/features/siege/domain/siege_record.dart';
import 'package:odin_guild_app/features/siege/presentation/siege_screen.dart';
import 'package:odin_guild_app/features/support/data/support_repository.dart';
import 'package:odin_guild_app/features/support/domain/support_request.dart';
import 'package:odin_guild_app/features/support/presentation/support_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('Dark Blue 로그인 화면 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: _PreviewApp(theme: _PreviewTheme.dark, child: LoginScreen()),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(LoginScreen)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/login_dark_blue.png'),
    );
  });

  testWidgets('Sand Gold 홈 화면 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PreviewHomeAuthController.new),
          scheduleRepositoryProvider.overrideWithValue(
            _PreviewScheduleRepository(),
          ),
          bossVoteRepositoryProvider.overrideWithValue(
            _PreviewVoteRepository(),
          ),
          noticeRepositoryProvider.overrideWithValue(
            _PreviewNoticeRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            _PreviewSettingsRepository(),
          ),
          serverClockProvider.overrideWithValue(_FixedServerClock()),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/home_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 보스 스케줄 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            _ScheduleScreenPreviewRepository(),
          ),
          serverClockProvider.overrideWithValue(_FixedServerClock()),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ScheduleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/schedule_dark_blue.png'),
    );
  });

  testWidgets('참여 보스 설정은 본섭과 침공을 구분한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
          scheduleRepositoryProvider.overrideWithValue(
            _ScheduleCreatePreviewRepository(),
          ),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ScheduleCreateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('참여 보스 설정'));
    await tester.tap(find.text('참여 보스 설정'));
    await tester.pumpAndSettle();

    expect(find.text('본섭'), findsAtLeastNWidgets(1));
    expect(find.text('침공'), findsAtLeastNWidgets(1));
    expect(find.text('파르바'), findsNWidgets(2));
  });

  testWidgets('공통 참여 보스 칩은 같은 폭으로 정렬된다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
          scheduleRepositoryProvider.overrideWithValue(
            _ScheduleCreatePreviewRepository(),
          ),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ScheduleCreateScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('참여 보스 설정'));
    await tester.tap(find.text('참여 보스 설정'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('participation-target-3')),
    );

    final first = tester.getSize(
      find.byKey(const ValueKey<String>('participation-target-3')),
    );
    final second = tester.getSize(
      find.byKey(const ValueKey<String>('participation-target-4')),
    );
    expect(first.width, second.width);
  });

  testWidgets('Sand Gold 내 정보 설정 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_PreviewAuthRepository()),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/profile_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 내 정보 설정 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_PreviewAuthRepository()),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/profile_dark_blue.png'),
    );
  });

  testWidgets('Dark Blue 길드원 목록 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: MembersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/members_dark_blue.png'),
    );
  });

  testWidgets('Sand Gold 길드원 장비 비교 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: MembersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('장비').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/members_equipment_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 길드원 스킬 비교 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: MembersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('스킬').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/members_skill_dark_blue.png'),
    );
  });

  testWidgets('Sand Gold 길드원 상세 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: MemberDetailScreen(memberId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/member_detail_sand_gold.png'),
    );
  });

  testWidgets('Sand Gold 공지 길드룰 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(
            _NoticeScreenPreviewRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: NoticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 보기').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/notices_rules_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 공지 보스 통제 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(
            _NoticeScreenPreviewRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: NoticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('보스 통제'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/notices_controls_dark_blue.png'),
    );
  });

  testWidgets('일반 길드원은 공지를 읽기 전용으로 이용한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(
            _NoticeScreenPreviewRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: NoticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('읽기 전용'), findsOneWidget);
    expect(find.byTooltip('길드룰 등록'), findsNothing);
    expect(find.byTooltip('관리 메뉴'), findsNothing);
  });

  testWidgets('운영진은 길드룰 등록 편집기를 열 수 있다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeRepositoryProvider.overrideWithValue(
            _NoticeScreenPreviewRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: NoticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드룰 등록'));
    await tester.pumpAndSettle();

    expect(find.text('새로 등록 · 길드룰'), findsOneWidget);
    expect(find.text('상단 안내'), findsOneWidget);
    expect(find.text('내규 섹션'), findsOneWidget);
  });

  testWidgets('Sand Gold 개인 아이템 현황 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(
            _PreviewCollectionRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: CollectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/collections_personal_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 아이템 기준 길드 비교 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(
            _PreviewCollectionRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: CollectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 비교'));
    await tester.pumpAndSettle();

    expect(find.text('아이템 기준'), findsOneWidget);
    expect(find.text('길드원 현황 3명'), findsWidgets);

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/collections_guild_dark_blue.png'),
    );
  });

  testWidgets('아이템 상세에서 길드원 전투력과 보유 필터를 표시한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(
            _PreviewCollectionRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: CollectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 비교'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드원 현황 3명').first);
    await tester.pumpAndSettle();

    expect(find.text('전체 3'), findsOneWidget);
    expect(find.text('미보유 1'), findsOneWidget);
    expect(find.text('보유 2'), findsOneWidget);
    expect(find.textContaining('전투력 129,800'), findsOneWidget);
  });

  testWidgets('길드원 50명도 아이템 카드에서는 요약하고 상세에서 필터링한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(
            _LargePreviewCollectionRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: CollectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 비교'));
    await tester.pumpAndSettle();

    expect(find.text('길드원 현황 50명'), findsOneWidget);
    expect(find.text('보유 25명 · 미보유 25명'), findsOneWidget);

    await tester.tap(find.text('길드원 현황 50명'));
    await tester.pumpAndSettle();

    expect(find.text('전체 50'), findsOneWidget);
    expect(find.text('미보유 25'), findsOneWidget);
    expect(find.text('보유 25'), findsOneWidget);
  });

  testWidgets('일반 길드원에게 컬렉션 관리 메뉴를 노출하지 않는다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionRepositoryProvider.overrideWithValue(
            _PreviewCollectionRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: CollectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('컬렉션 추가'), findsNothing);
    expect(find.byTooltip('우선순위 제외 관리'), findsNothing);
    expect(find.byTooltip('컬렉션 관리'), findsNothing);
  });

  testWidgets('Dark Blue 콘텐츠 참여 그룹 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentGroupRepositoryProvider.overrideWithValue(
            _PreviewContentGroupRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ContentGroupsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('발할라 1군'), findsOneWidget);
    expect(find.text('미편성 1'), findsOneWidget);
    expect(find.byTooltip('새 그룹 생성'), findsOneWidget);

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/content_groups_dark_blue.png'),
    );
  });

  testWidgets('콘텐츠 그룹 상세에서 전투력과 이동 대상을 확인한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentGroupRepositoryProvider.overrideWithValue(
            _PreviewContentGroupRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: ContentGroupsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 길드원 보기 2명'));
    await tester.pumpAndSettle();

    expect(find.textContaining('전투력 142,530'), findsWidgets);
    await tester.tap(find.byTooltip('그룹으로 이동').last);
    await tester.pumpAndSettle();

    expect(find.text('미편성'), findsWidgets);
    expect(find.text('발할라 2군'), findsWidgets);
  });

  testWidgets('일반 길드원은 콘텐츠 편성을 읽기 전용으로 조회한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentGroupRepositoryProvider.overrideWithValue(
            _PreviewContentGroupRepository(),
          ),
          memberRepositoryProvider.overrideWithValue(
            _PreviewMemberRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: ContentGroupsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('새 그룹 생성'), findsNothing);
    expect(find.byTooltip('그룹 관리'), findsNothing);
    expect(find.textContaining('변경은 운영진이 관리합니다'), findsOneWidget);
  });

  testWidgets('Dark Blue 공성전 현황 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siegeRepositoryProvider.overrideWithValue(_PreviewSiegeRepository()),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: SiegeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('길드 다이아 요약'), findsOneWidget);
    expect(find.text('115,000'), findsWidgets);
    expect(find.byTooltip('공성전 데이터 전체 초기화'), findsOneWidget);

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/siege_dark_blue.png'),
    );
  });

  testWidgets('Dark Blue 손지원 매칭 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(
            _PreviewSupportRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: SupportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('길드 손지원 현황'), findsOneWidget);
    expect(find.text('손지원 신청'), findsOneWidget);
    expect(find.text('지원자 2명'), findsOneWidget);
    expect(find.text('소서리스'), findsNothing);
    expect(find.text('아크 메이지'), findsOneWidget);
    expect(find.text('142,530'), findsOneWidget);

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/support_dark_blue.png'),
    );
  });

  testWidgets('손지원 요청 등록 시 날짜·종일·시간·메모를 입력한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(
            _PreviewSupportRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: SupportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '요청 등록'));
    await tester.pumpAndSettle();

    expect(find.text('손지원 요청 등록'), findsOneWidget);
    expect(find.text('요청 날짜'), findsOneWidget);
    expect(find.text('종일'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('운영진은 손지원 담당자를 선택하고 요청을 관리할 수 있다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(
            _PreviewSupportRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: SupportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('선택'), findsWidgets);
    expect(find.byTooltip('프레이야 요청 관리'), findsOneWidget);
  });

  testWidgets('운영진은 길드원 공성전 기록 수정 시트를 열 수 있다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siegeRepositoryProvider.overrideWithValue(_PreviewSiegeRepository()),
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: SiegeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('로키 기록 수정').last);
    await tester.pumpAndSettle();

    expect(find.text('로키 기록 수정'), findsOneWidget);
    expect(find.text('변경 내용 저장'), findsOneWidget);
    expect(find.textContaining('전투력 129,800'), findsWidgets);
  });

  testWidgets('일반 길드원은 본인 공성전 기록만 입력한다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siegeRepositoryProvider.overrideWithValue(_PreviewSiegeRepository()),
          authControllerProvider.overrideWith(_PreviewMemberAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: SiegeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내 공성전 기록'), findsOneWidget);
    expect(find.byTooltip('공성전 데이터 전체 초기화'), findsNothing);
    expect(find.byTooltip('프레이야 기록 수정'), findsNothing);
  });

  testWidgets('Sand Gold 마스터 설정 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _PreviewSettingsRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.sand,
          child: MasterSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/master_settings_sand_gold.png'),
    );
  });

  testWidgets('Dark Blue 마스터 설정 가입 코드 미리보기', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _PreviewSettingsRepository(),
          ),
          authControllerProvider.overrideWith(_PreviewAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: MasterSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppBackground),
      matchesGoldenFile('goldens/master_settings_invite_dark_blue.png'),
    );
  });

  testWidgets('운영진은 마스터 설정에 접근할 수 없다', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PreviewAdminAuthController.new),
        ],
        child: const _PreviewApp(
          theme: _PreviewTheme.dark,
          child: MasterSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('길드장 전용 메뉴예요'), findsOneWidget);
    expect(find.text('길드 설정 저장'), findsNothing);
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

enum _PreviewTheme { sand, dark }

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.theme, required this.child});

  final _PreviewTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme == _PreviewTheme.sand
          ? AppTheme.sandGold
          : AppTheme.darkBlue,
      builder: (context, content) =>
          AppBackground(child: content ?? const SizedBox.shrink()),
      home: child,
    );
  }
}

class _PreviewScheduleRepository implements ScheduleRepository {
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
    final now = DateTime.utc(2026, 8, 11, 3).millisecondsSinceEpoch;
    return ScheduleOverview(
      schedules: <BossSchedule>[
        BossSchedule(
          id: 1,
          bossDefinitionId: 1,
          type: '본섭',
          region: '요툰하임',
          boss: '파르바',
          spawnTime: now + const Duration(minutes: 18).inMilliseconds,
          isMung: false,
        ),
      ],
      participationTargetBossDefinitionIds: const <int>{1},
      participantsByVoteKey: const <String, List<String>>{},
      closedVoteKeys: const <String>{},
      synchronizedAt: DateTime.utc(2026, 8, 11, 3),
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

class _FixedServerClock extends ServerClock {
  @override
  DateTime now({DateTime? localNow}) => DateTime.utc(2026, 8, 11, 3);
}

class _ScheduleScreenPreviewRepository extends _PreviewScheduleRepository {
  @override
  Future<ScheduleOverview> fetchOverview() async {
    final now = DateTime.utc(2026, 8, 11, 3).millisecondsSinceEpoch;
    final past = BossSchedule(
      id: 1,
      bossDefinitionId: 1,
      type: '본섭',
      region: '요툰하임',
      boss: '파르바',
      spawnTime: now - const Duration(minutes: 12).inMilliseconds,
      isMung: false,
    );
    final next = BossSchedule(
      id: 2,
      bossDefinitionId: 2,
      type: '공통',
      region: '던전',
      boss: '분노의 모네가름',
      spawnTime: now + const Duration(minutes: 4, seconds: 20).inMilliseconds,
      isMung: false,
    );
    final invasion = BossSchedule(
      id: 3,
      bossDefinitionId: 3,
      type: '침공',
      region: '니플하임',
      boss: '수르트',
      spawnTime: now + const Duration(minutes: 48).inMilliseconds,
      isMung: false,
    );
    return ScheduleOverview(
      schedules: <BossSchedule>[past, next, invasion],
      participationTargetBossDefinitionIds: const <int>{2, 3},
      participantsByVoteKey: <String, List<String>>{
        next.voteKey: const <String>['오딘', '토르', '프레이야'],
      },
      closedVoteKeys: const <String>{},
      synchronizedAt: DateTime.utc(2026, 8, 11, 3),
    );
  }
}

class _ScheduleCreatePreviewRepository extends _PreviewScheduleRepository {
  @override
  Future<List<BossDefinition>> fetchBossDefinitions() async =>
      const <BossDefinition>[
        BossDefinition(
          id: 1,
          type: '본섭',
          region: '요툰하임',
          boss: '파르바',
          cooldownHours: 12,
        ),
        BossDefinition(
          id: 2,
          type: '침공',
          region: '니플하임',
          boss: '파르바',
          cooldownHours: 12,
        ),
        BossDefinition(
          id: 3,
          type: '공통',
          region: '공통',
          boss: '10층 다인홀로크',
          cooldownHours: 12,
        ),
        BossDefinition(
          id: 4,
          type: '공통',
          region: '공통',
          boss: '4층 분노의 모네가름',
          cooldownHours: 12,
        ),
        BossDefinition(
          id: 5,
          type: '공통',
          region: '공통',
          boss: '7층 나테이드라우그',
          cooldownHours: 12,
        ),
      ];
}

class _PreviewVoteRepository implements BossVoteRepository {
  @override
  Future<List<VoteBoss>> fetchVoteBosses() async => const <VoteBoss>[];

  @override
  Future<void> createManualVote(ManualVoteInput input) async {}

  @override
  Future<bool> toggleParticipation(VoteBoss voteBoss) async => true;
}

class _PreviewNoticeRepository implements NoticeRepository {
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

class _NoticeScreenPreviewRepository implements NoticeRepository {
  @override
  Future<NoticeOverview> fetchOverview() async => NoticeOverview(
    rules: <NoticeArticle>[
      NoticeArticle(
        id: 1,
        title: '길드 운영 내규',
        content:
            '상단 안내 >  > 서로 존중하며 즐겁게 플레이하는 길드를 지향합니다.\n'
            '길드 내규 > 보스 참여 > 참여 가능 여부를 미리 표시해 주세요.\n'
            '길드 내규 > 분쟁 대응 > 개인 대응보다 운영진에게 먼저 알려 주세요.\n'
            '마무리 >  > 적용일: 공지 즉시',
        color: '#F2B705',
        updatedAt: DateTime.utc(2026, 8, 11, 1, 20),
      ),
      NoticeArticle(
        id: 2,
        title: '길드 채팅 안내',
        content: '안내 > 기본 예절 > 과도한 비방과 분쟁 유도는 삼가 주세요.',
        color: '#3b82f6',
        updatedAt: DateTime.utc(2026, 8, 10, 11),
      ),
    ],
    priceGuides: <NoticeArticle>[
      NoticeArticle(
        id: 3,
        title: '전설 · 신화 아이템',
        content:
            '전설 방어구 > 발키리 갑옷 > 15000\n'
            '전설 방어구 > 발키리 투구 > 무상 지원',
        color: '#fbbf24',
        updatedAt: DateTime.utc(2026, 8, 11, 2),
      ),
    ],
    bossControls: <BossControlChapter>[
      BossControlChapter(
        chapter: '요툰하임',
        bosses: <BossControl>[
          BossControl(name: '파르바', status: 'CONTROL'),
          BossControl(name: '셀로비아', status: 'ALLY_ONLY'),
          BossControl(name: '흐니르', status: 'NONE'),
          BossControl(name: '페티', status: 'NONE'),
        ],
      ),
      BossControlChapter(
        chapter: '니다벨리르',
        bosses: <BossControl>[
          BossControl(name: '라이노르', status: 'ALLY_ONLY'),
          BossControl(name: '비요른', status: 'NONE'),
        ],
      ),
    ],
  );

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

class _PreviewCollectionRepository implements CollectionRepository {
  @override
  Future<CollectionOverview> fetchOverview() async => CollectionOverview(
    collections: const <ItemCollection>[
      ItemCollection(
        id: 1,
        name: '전설 방어구',
        items: <CollectionItem>[
          CollectionItem(id: 10, part: '발키리 갑옷', enchantment: '강화 7'),
          CollectionItem(id: 11, part: '발키리 투구', enchantment: '강화 6'),
        ],
      ),
      ItemCollection(
        id: 2,
        name: '희귀 장신구',
        items: <CollectionItem>[
          CollectionItem(id: 20, part: '서리 목걸이', enchantment: '강화 5'),
          CollectionItem(id: 21, part: '빛의 반지', enchantment: '강화 4'),
        ],
      ),
    ],
    members: const <CollectionMember>[
      CollectionMember(
        id: 7,
        nickname: '프레이야',
        combatPower: 142530,
        role: UserRole.master,
      ),
      CollectionMember(
        id: 8,
        nickname: '토르',
        combatPower: 137420,
        role: UserRole.admin,
      ),
      CollectionMember(
        id: 9,
        nickname: '로키',
        combatPower: 129800,
        role: UserRole.member,
      ),
    ],
    completedKeys: <String>{
      CollectionOverview.statusKey(7, 10),
      CollectionOverview.statusKey(7, 20),
      CollectionOverview.statusKey(8, 10),
      CollectionOverview.statusKey(9, 11),
    },
    excludedMemberIds: const <int>{9},
    synchronizedAt: DateTime(2026, 8, 11, 10, 40),
  );

  @override
  Future<void> deleteCollection(int collectionId) async {}

  @override
  Future<void> saveCollection(
    CollectionInput input, {
    int? collectionId,
  }) async {}

  @override
  Future<void> setCompleted({
    required int userId,
    required int itemId,
    required bool completed,
  }) async {}

  @override
  Future<bool> toggleExcluded(int userId) async => true;
}

class _LargePreviewCollectionRepository extends _PreviewCollectionRepository {
  @override
  Future<CollectionOverview> fetchOverview() async {
    final members = List<CollectionMember>.generate(
      50,
      (index) => CollectionMember(
        id: 100 + index,
        nickname: '길드원 ${index + 1}',
        combatPower: 200000 - (index * 1000),
        role: UserRole.member,
      ),
    );
    return CollectionOverview(
      collections: const <ItemCollection>[
        ItemCollection(
          id: 1,
          name: '전설 방어구',
          items: <CollectionItem>[
            CollectionItem(id: 10, part: '발키리 갑옷', enchantment: '강화 7'),
          ],
        ),
      ],
      members: members,
      completedKeys: <String>{
        for (var index = 0; index < 50; index += 2)
          CollectionOverview.statusKey(100 + index, 10),
      },
      excludedMemberIds: const <int>{},
      synchronizedAt: DateTime(2026, 8, 11, 10, 40),
    );
  }
}

class _PreviewAuthRepository implements AuthRepository {
  @override
  Future<void> deleteMe({required String password}) async {}

  @override
  Future<UserProfile> fetchMe() async {
    return const UserProfile(
      id: 7,
      username: 'odin_master',
      role: UserRole.master,
      nickname: '프레이야',
      occupation: '소서리스',
      mainClass: '아크 메이지',
      combatPower: 123456,
      maxCritRate: 52.3,
      maxCritResist: 41.2,
      statusEffectAccuracy: 18.5,
      alternateCharacters: <AlternateCharacter>[
        AlternateCharacter(characterName: '프레이야2', mainClass: '바드'),
      ],
      equipment: <String, dynamic>{
        '무기': <String, String>{'val': '발뭉 7강', 'color': 'legend'},
        '투구': <String, String>{'val': '신화 투구', 'color': 'mythic'},
      },
      skills: <String, dynamic>{
        'active': <String, String>{'영웅 1': '5강', '전설 1': '1강'},
        'passive': <String, String>{'영웅 1': '3강'},
      },
    );
  }

  @override
  Future<ProfileSettings> fetchProfileSettings() async {
    return const ProfileSettings(allowCombatPowerEdit: false);
  }

  @override
  Future<Session> login({required String username, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<String?> register(RegistrationRequest request) async => null;

  @override
  Future<void> updateMe(ProfileUpdateRequest request) async {}
}

class _PreviewAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'preview-token',
      userId: 7,
      username: 'odin_master',
      nickname: '프레이야',
      role: UserRole.master,
    );
  }
}

class _PreviewHomeAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'preview-token',
      userId: 7,
      username: 'odin_master',
      nickname: '',
      role: UserRole.unknown,
    );
  }
}

class _PreviewAdminAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'preview-token',
      userId: 8,
      username: 'odin_admin',
      nickname: '토르',
      role: UserRole.admin,
    );
  }
}

class _PreviewMemberAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'preview-token',
      userId: 9,
      username: 'odin_member',
      nickname: '로키',
      role: UserRole.member,
    );
  }
}

class _PreviewMemberRepository implements MemberRepository {
  @override
  Future<List<GuildMember>> fetchMembers() async => _previewMembers;

  @override
  Future<List<GuildMember>> fetchContentGroupRoster() async => _previewMembers;

  @override
  Future<void> changeRole(int memberId, UserRole role) async {}

  @override
  Future<void> transferGuildMaster(int memberId) async {}

  @override
  Future<void> removeMember(int memberId) async {}

  @override
  Future<void> resetPassword(int memberId) async {}
}

class _PreviewContentGroupRepository implements ContentGroupRepository {
  @override
  Future<List<ContentGroup>> fetchGroups() async => const <ContentGroup>[
    ContentGroup(id: 1, name: '발할라 1군', memberIds: <int>[7, 8]),
    ContentGroup(id: 2, name: '발할라 2군', memberIds: <int>[]),
  ];

  @override
  Future<ContentGroup> createGroup(String name) async {
    return ContentGroup(id: 3, name: name, memberIds: const <int>[]);
  }

  @override
  Future<void> deleteGroup(int groupId) async {}

  @override
  Future<void> renameGroup(int groupId, String name) async {}

  @override
  Future<void> saveMembers(int groupId, List<int> memberIds) async {}
}

class _PreviewSiegeRepository implements SiegeRepository {
  @override
  Future<List<SiegeRecord>> fetchRecords() async => <SiegeRecord>[
    SiegeRecord(
      userId: 7,
      nickname: '프레이야',
      mainClass: '아크 메이지',
      combatPower: 142530,
      startDiamonds: 120000,
      remainingDiamonds: 45000,
      updatedAt: DateTime(2026, 8, 11, 9, 20),
    ),
    SiegeRecord(
      userId: 8,
      nickname: '토르',
      mainClass: '디펜더',
      combatPower: 137420,
      startDiamonds: 80000,
      remainingDiamonds: 40000,
      updatedAt: DateTime(2026, 8, 11, 9, 35),
    ),
    const SiegeRecord(
      userId: 9,
      nickname: '로키',
      mainClass: '어쌔신',
      combatPower: 129800,
      startDiamonds: 0,
      remainingDiamonds: 0,
      updatedAt: null,
    ),
  ];

  @override
  Future<void> resetAll() async {}

  @override
  Future<void> saveMember(int userId, SiegeInput input) async {}

  @override
  Future<void> saveMine(SiegeInput input) async {}
}

class _PreviewSupportRepository implements SupportRepository {
  @override
  Future<List<SupportRequest>> fetchRequests() async => <SupportRequest>[
    const SupportRequest(
      id: 1,
      requesterId: 7,
      requestedTime: '2026-08-12 20:00~21:30',
      memo: '월드 보스 입장 전 장비와 스킬 세팅을 도와주세요.',
      status: SupportRequestStatus.open,
      selectedApplicationId: null,
      createdAt: null,
      updatedAt: null,
      nickname: '프레이야',
      occupation: '소서리스',
      mainClass: '아크 메이지',
      combatPower: 142530,
      applications: <SupportApplication>[
        SupportApplication(
          id: 11,
          requestId: 1,
          applicantId: 8,
          memo: '',
          status: SupportApplicationStatus.applied,
          createdAt: null,
          nickname: '토르',
          occupation: '워리어',
          mainClass: '디펜더',
          combatPower: 137420,
        ),
        SupportApplication(
          id: 12,
          requestId: 1,
          applicantId: 10,
          memo: '',
          status: SupportApplicationStatus.applied,
          createdAt: null,
          nickname: '헤임달',
          occupation: '프리스트',
          mainClass: '세인트',
          combatPower: 126800,
        ),
      ],
    ),
    const SupportRequest(
      id: 2,
      requesterId: 8,
      requestedTime: '2026-08-13 종일',
      memo: '신규 장비 옵션 상담이 필요합니다.',
      status: SupportRequestStatus.matched,
      selectedApplicationId: 21,
      createdAt: null,
      updatedAt: null,
      nickname: '토르',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 137420,
      applications: <SupportApplication>[
        SupportApplication(
          id: 21,
          requestId: 2,
          applicantId: 9,
          memo: '',
          status: SupportApplicationStatus.selected,
          createdAt: null,
          nickname: '로키',
          occupation: '로그',
          mainClass: '어쌔신',
          combatPower: 129800,
        ),
      ],
    ),
    const SupportRequest(
      id: 3,
      requesterId: 9,
      requestedTime: '2026-08-10 22:00',
      memo: '완료된 요청',
      status: SupportRequestStatus.done,
      selectedApplicationId: null,
      createdAt: null,
      updatedAt: null,
      nickname: '로키',
      occupation: '로그',
      mainClass: '어쌔신',
      combatPower: 129800,
      applications: <SupportApplication>[],
    ),
  ];

  @override
  Future<void> apply(int requestId, {String memo = ''}) async {}

  @override
  Future<void> cancelApplication(int requestId, int applicationId) async {}

  @override
  Future<void> createRequest(SupportRequestInput input) async {}

  @override
  Future<void> deleteRequest(int requestId) async {}

  @override
  Future<void> selectApplication(int requestId, int applicationId) async {}

  @override
  Future<void> updateStatus(int requestId, SupportRequestStatus status) async {}
}

class _PreviewSettingsRepository implements SettingsRepository {
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
      GuildInvite(code: 'PREVIEW-CODE', role: UserRole.member),
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
      code: customCode.isEmpty ? 'PREVIEW-CODE' : customCode,
      role: role,
    );
  }
}

const _previewMembers = <GuildMember>[
  GuildMember(
    id: 7,
    role: UserRole.master,
    nickname: '프레이야',
    occupation: '소서리스',
    mainClass: '아크 메이지',
    combatPower: 142530,
    maxCritRate: 52.3,
    maxCritResist: 41.2,
    statusEffectAccuracy: 18.5,
    equipment: <String, MemberEquipment>{
      '무기': MemberEquipment(value: '발뭉 7강', grade: 'legend'),
      '보조무기': MemberEquipment(value: '마력 보주', grade: 'hero'),
      '투구': MemberEquipment(value: '신화 투구', grade: 'mythic'),
      '갑옷': MemberEquipment(value: '발키리 갑옷', grade: 'legend'),
    },
    activeSkills: <String, String>{
      '영웅 1': '8강',
      '영웅 2': '5강',
      '영웅 3': 'X',
      '영웅 4': '3강',
      '전설 1': '1강',
      '전설 2': 'X',
    },
    passiveSkills: <String, String>{
      '영웅 1': '6강',
      '영웅 2': '4강',
      '영웅 3': 'X',
      '영웅 4': 'X',
      '전설 1': '1강',
      '전설 2': 'X',
    },
    alternateCharacters: <AlternateCharacter>[
      AlternateCharacter(characterName: '프레이야2', mainClass: '바드'),
    ],
  ),
  GuildMember(
    id: 8,
    role: UserRole.admin,
    nickname: '토르',
    occupation: '워리어',
    mainClass: '디펜더',
    combatPower: 137420,
    maxCritRate: 47.8,
    maxCritResist: 55.1,
    statusEffectAccuracy: 13,
    equipment: <String, MemberEquipment>{},
    activeSkills: <String, String>{},
    passiveSkills: <String, String>{},
    alternateCharacters: <AlternateCharacter>[],
  ),
  GuildMember(
    id: 9,
    role: UserRole.member,
    nickname: '로키',
    occupation: '로그',
    mainClass: '어쌔신',
    combatPower: 129800,
    maxCritRate: 58.2,
    maxCritResist: 38.4,
    statusEffectAccuracy: 22.7,
    equipment: <String, MemberEquipment>{},
    activeSkills: <String, String>{},
    passiveSkills: <String, String>{},
    alternateCharacters: <AlternateCharacter>[],
  ),
];
