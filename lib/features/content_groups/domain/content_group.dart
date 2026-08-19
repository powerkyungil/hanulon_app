import '../../members/domain/guild_member.dart';

class ContentGroup {
  const ContentGroup({
    required this.id,
    required this.name,
    required this.memberIds,
  });

  final int id;
  final String name;
  final List<int> memberIds;

  ContentGroup copyWith({String? name, List<int>? memberIds}) {
    return ContentGroup(
      id: id,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

class ContentGroupOverview {
  const ContentGroupOverview({
    required this.groups,
    required this.members,
    required this.synchronizedAt,
  });

  final List<ContentGroup> groups;
  final List<GuildMember> members;
  final DateTime synchronizedAt;

  Set<int> get assignedMemberIds =>
      groups.expand((group) => group.memberIds).toSet();

  List<GuildMember> get sortedMembers {
    final result = List<GuildMember>.of(members);
    result.sort((a, b) => b.combatPower.compareTo(a.combatPower));
    return result;
  }

  List<GuildMember> get unassignedMembers => sortedMembers
      .where((member) => !assignedMemberIds.contains(member.id))
      .toList();

  List<GuildMember> membersFor(ContentGroup group) {
    final ids = group.memberIds.toSet();
    return sortedMembers.where((member) => ids.contains(member.id)).toList();
  }

  ContentGroup? groupForMember(int memberId) {
    return groups
        .where((group) => group.memberIds.contains(memberId))
        .firstOrNull;
  }

  ContentGroupOverview copyWith({
    List<ContentGroup>? groups,
    List<GuildMember>? members,
    DateTime? synchronizedAt,
  }) {
    return ContentGroupOverview(
      groups: groups ?? this.groups,
      members: members ?? this.members,
      synchronizedAt: synchronizedAt ?? this.synchronizedAt,
    );
  }
}
