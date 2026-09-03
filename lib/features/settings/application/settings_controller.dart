import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../data/settings_repository.dart';
import '../domain/guild_invite.dart';
import '../domain/guild_settings.dart';

class SettingsController extends AsyncNotifier<GuildSettings> {
  @override
  Future<GuildSettings> build() {
    final userId = ref.watch(
      authControllerProvider.select((state) => state.value?.userId),
    );
    if (userId == null) {
      return Future<GuildSettings>.value(
        const GuildSettings(guildName: '', allowMemberCombatPowerEdit: false),
      );
    }
    return ref.read(settingsRepositoryProvider).fetchSettings();
  }

  Future<List<GuildInvite>> fetchInvites() {
    return ref.read(settingsRepositoryProvider).fetchInvites();
  }

  Future<void> save(GuildSettings settings) async {
    await ref.read(settingsRepositoryProvider).saveSettings(settings);
    state = AsyncData(settings);
  }

  Future<GuildInvite> createInvite(UserRole role, {String customCode = ''}) {
    return ref
        .read(settingsRepositoryProvider)
        .createInvite(role, customCode: customCode);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, GuildSettings>(
      SettingsController.new,
    );
