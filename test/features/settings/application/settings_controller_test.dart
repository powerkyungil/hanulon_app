import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/settings/application/settings_controller.dart';
import 'package:odin_guild_app/features/settings/data/settings_repository.dart';
import 'package:odin_guild_app/features/settings/domain/guild_invite.dart';
import 'package:odin_guild_app/features/settings/domain/guild_settings.dart';

void main() {
  test('로그인 계정이 바뀌면 길드 설정을 다시 불러온다', () async {
    final repository = _FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SwitchableAuthController.new),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final signedOutSettings = await container.read(
      settingsControllerProvider.future,
    );

    expect(signedOutSettings.guildName, isEmpty);
    expect(repository.fetchCount, 0);

    final authController =
        container.read(authControllerProvider.notifier)
            as _SwitchableAuthController;
    authController.setSession(_session(userId: 1, username: 'first'));
    final firstSettings = await container.read(
      settingsControllerProvider.future,
    );

    expect(firstSettings.guildName, '첫 번째 길드');
    expect(repository.fetchCount, 1);

    authController.setSession(_session(userId: 2, username: 'second'));
    final secondSettings = await container.read(
      settingsControllerProvider.future,
    );

    expect(secondSettings.guildName, '두 번째 길드');
    expect(repository.fetchCount, 2);
  });
}

Session _session({required int userId, required String username}) {
  return Session(
    accessToken: 'token-$userId',
    userId: userId,
    username: username,
    nickname: username,
    role: UserRole.master,
  );
}

class _SwitchableAuthController extends AuthController {
  @override
  Future<Session?> build() async => null;

  void setSession(Session session) {
    state = AsyncData<Session?>(session);
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  int fetchCount = 0;

  @override
  Future<GuildSettings> fetchSettings() async {
    fetchCount += 1;
    return GuildSettings(
      guildName: fetchCount == 1 ? '첫 번째 길드' : '두 번째 길드',
      allowMemberCombatPowerEdit: false,
    );
  }

  @override
  Future<GuildInvite> createInvite(UserRole role, {String customCode = ''}) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuildInvite>> fetchInvites() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSettings(GuildSettings settings) {
    throw UnimplementedError();
  }
}
