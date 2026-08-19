import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../data/member_repository.dart';
import '../domain/guild_member.dart';

class MembersController extends AsyncNotifier<List<GuildMember>> {
  @override
  Future<List<GuildMember>> build() {
    return ref.read(memberRepositoryProvider).fetchMembers();
  }

  Future<void> refreshMembers() async {
    state = const AsyncLoading<List<GuildMember>>();
    try {
      final members = await ref.read(memberRepositoryProvider).fetchMembers();
      state = AsyncData<List<GuildMember>>(members);
    } catch (error, stackTrace) {
      state = AsyncError<List<GuildMember>>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> changeRole(GuildMember member, UserRole role) async {
    await ref.read(memberRepositoryProvider).changeRole(member.id, role);
    await refreshMembers();
  }

  Future<void> transferGuildMaster(GuildMember member) async {
    await ref.read(memberRepositoryProvider).transferGuildMaster(member.id);
    ref
        .read(authControllerProvider.notifier)
        .updateCurrentRole(UserRole.member);
    await refreshMembers();
  }

  Future<void> resetPassword(GuildMember member) {
    return ref.read(memberRepositoryProvider).resetPassword(member.id);
  }

  Future<void> removeMember(GuildMember member) async {
    await ref.read(memberRepositoryProvider).removeMember(member.id);
    await refreshMembers();
  }
}

final membersControllerProvider =
    AsyncNotifierProvider<MembersController, List<GuildMember>>(
      MembersController.new,
    );
