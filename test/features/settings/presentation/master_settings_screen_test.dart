import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/settings/data/settings_repository.dart';
import 'package:odin_guild_app/features/settings/domain/guild_invite.dart';
import 'package:odin_guild_app/features/settings/domain/guild_settings.dart';
import 'package:odin_guild_app/features/settings/presentation/master_settings_screen.dart';

void main() {
  testWidgets('가입 코드 변경 저장 버튼으로 새 코드를 저장한다', (tester) async {
    final repository = _FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_MasterAuthController.new),
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.darkBlue,
          home: const MasterSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('가입 코드 저장'), findsOneWidget);
    expect(find.byIcon(Icons.save_rounded), findsOneWidget);

    final inviteField = find.byType(TextFormField).last;
    await tester.ensureVisible(inviteField);
    await tester.enterText(inviteField, 'NEW-CODE');
    await tester.pump();

    final saveButton = find.text('가입 코드 변경 저장');
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('가입 코드를 변경할까요?'), findsOneWidget);
    await tester.tap(find.text('코드 변경'));
    await tester.pumpAndSettle();

    expect(repository.savedInviteCode, 'NEW-CODE');
    expect(find.text('가입 코드를 저장했습니다.'), findsOneWidget);
  });
}

class _MasterAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'test-token',
      userId: 1,
      username: 'master',
      nickname: '길드장',
      role: UserRole.master,
    );
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  String? savedInviteCode;

  @override
  Future<GuildSettings> fetchSettings() async {
    return const GuildSettings(
      guildName: '테스트 길드',
      allowMemberCombatPowerEdit: true,
    );
  }

  @override
  Future<List<GuildInvite>> fetchInvites() async {
    return const <GuildInvite>[
      GuildInvite(code: 'CURRENT-CODE', role: UserRole.member),
    ];
  }

  @override
  Future<GuildInvite> createInvite(
    UserRole role, {
    String customCode = '',
  }) async {
    savedInviteCode = customCode;
    return GuildInvite(code: customCode, role: role);
  }

  @override
  Future<void> saveSettings(GuildSettings settings) async {}
}
