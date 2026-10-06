import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../members/data/member_repository.dart';
import '../../members/domain/guild_member.dart';
import '../data/content_group_repository.dart';
import '../domain/content_group.dart';

class ContentGroupController extends AsyncNotifier<ContentGroupOverview> {
  @override
  Future<ContentGroupOverview> build() => _fetchOverview();

  Future<ContentGroupOverview> _fetchOverview() async {
    final result = await Future.wait<Object>(<Future<Object>>[
      ref.read(contentGroupRepositoryProvider).fetchGroups(),
      ref.read(memberRepositoryProvider).fetchContentGroupRoster(),
    ]);
    return ContentGroupOverview(
      groups: result[0] as List<ContentGroup>,
      members: result[1] as List<GuildMember>,
      synchronizedAt: DateTime.now(),
    );
  }

  Future<void> refreshOverview() async {
    state = AsyncData(await _fetchOverview());
  }

  Future<void> createGroup(String name) async {
    await ref.read(contentGroupRepositoryProvider).createGroup(name);
    await refreshOverview();
  }

  Future<void> renameGroup(ContentGroup group, String name) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        groups: current.groups
            .map(
              (item) => item.id == group.id ? item.copyWith(name: name) : item,
            )
            .toList(),
      ),
    );
    try {
      await ref
          .read(contentGroupRepositoryProvider)
          .renameGroup(group.id, name);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> deleteGroup(ContentGroup group) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        groups: current.groups.where((item) => item.id != group.id).toList(),
      ),
    );
    try {
      await ref.read(contentGroupRepositoryProvider).deleteGroup(group.id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> moveMember(int memberId, {int? targetGroupId}) async {
    final current = state.value;
    if (current == null) return;
    final currentGroupId = current.groupForMember(memberId)?.id;
    if (currentGroupId == targetGroupId) return;

    final affectedIds = <int>{
      if (currentGroupId != null) currentGroupId,
      if (targetGroupId != null) targetGroupId,
    };
    final updatedGroups = current.groups.map((group) {
      final ids = group.memberIds.where((id) => id != memberId).toList();
      if (group.id == targetGroupId) ids.add(memberId);
      return group.copyWith(memberIds: ids);
    }).toList();
    final updated = current.copyWith(groups: updatedGroups);
    state = AsyncData(updated);

    final repository = ref.read(contentGroupRepositoryProvider);
    try {
      for (final groupId in affectedIds) {
        final group = updatedGroups.firstWhere((item) => item.id == groupId);
        await repository.saveMembers(groupId, group.memberIds);
      }
    } catch (_) {
      for (final groupId in affectedIds) {
        try {
          final original = current.groups.firstWhere(
            (item) => item.id == groupId,
          );
          await repository.saveMembers(groupId, original.memberIds);
        } catch (_) {
          // The next manual refresh reconciles a failed compensation request.
        }
      }
      state = AsyncData(current);
      rethrow;
    }
  }
}

final contentGroupOverviewProvider =
    AsyncNotifierProvider<ContentGroupController, ContentGroupOverview>(
      ContentGroupController.new,
    );
