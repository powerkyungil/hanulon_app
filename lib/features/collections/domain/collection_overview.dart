import '../../auth/domain/user_role.dart';
import 'item_collection.dart';

class CollectionOverview {
  const CollectionOverview({
    required this.collections,
    required this.members,
    required this.completedKeys,
    required this.excludedMemberIds,
    required this.synchronizedAt,
  });

  final List<ItemCollection> collections;
  final List<CollectionMember> members;
  final Set<String> completedKeys;
  final Set<int> excludedMemberIds;
  final DateTime synchronizedAt;

  int get itemCount => collections.fold<int>(
    0,
    (total, collection) => total + collection.items.length,
  );

  bool isCompleted(int userId, int itemId) {
    return completedKeys.contains(statusKey(userId, itemId));
  }

  int completedCount(int userId) {
    return collections.fold<int>(
      0,
      (total, collection) =>
          total +
          collection.items.where((item) => isCompleted(userId, item.id)).length,
    );
  }

  int completionPercent(int userId) {
    if (itemCount == 0) return 0;
    return (completedCount(userId) / itemCount * 100).round();
  }

  CollectionPriority? priorityFor(int itemId) {
    for (final member in members) {
      if (!excludedMemberIds.contains(member.id) &&
          !isCompleted(member.id, itemId)) {
        return CollectionPriority(member: member, isExcluded: false);
      }
    }
    for (final member in members) {
      if (excludedMemberIds.contains(member.id) &&
          !isCompleted(member.id, itemId)) {
        return CollectionPriority(member: member, isExcluded: true);
      }
    }
    return null;
  }

  CollectionOverview withCompletion({
    required int userId,
    required int itemId,
    required bool completed,
  }) {
    final keys = Set<String>.of(completedKeys);
    final key = statusKey(userId, itemId);
    if (completed) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    return copyWith(completedKeys: keys);
  }

  CollectionOverview withExcluded(int userId, bool excluded) {
    final ids = Set<int>.of(excludedMemberIds);
    if (excluded) {
      ids.add(userId);
    } else {
      ids.remove(userId);
    }
    return copyWith(excludedMemberIds: ids);
  }

  CollectionOverview copyWith({
    List<ItemCollection>? collections,
    List<CollectionMember>? members,
    Set<String>? completedKeys,
    Set<int>? excludedMemberIds,
    DateTime? synchronizedAt,
  }) {
    return CollectionOverview(
      collections: collections ?? this.collections,
      members: members ?? this.members,
      completedKeys: completedKeys ?? this.completedKeys,
      excludedMemberIds: excludedMemberIds ?? this.excludedMemberIds,
      synchronizedAt: synchronizedAt ?? this.synchronizedAt,
    );
  }

  static String statusKey(int userId, int itemId) => '$userId:$itemId';
}

class CollectionMember {
  const CollectionMember({
    required this.id,
    required this.nickname,
    required this.combatPower,
    required this.role,
  });

  final int id;
  final String nickname;
  final int combatPower;
  final UserRole role;
}

class CollectionPriority {
  const CollectionPriority({required this.member, required this.isExcluded});

  final CollectionMember member;
  final bool isExcluded;
}
