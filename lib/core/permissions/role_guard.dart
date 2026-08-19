import '../../features/auth/domain/user_role.dart';

abstract final class RoleGuard {
  static bool isStaff(UserRole role) {
    return role == UserRole.master || role == UserRole.admin;
  }

  static bool isMaster(UserRole role) => role == UserRole.master;

  static bool canManageOperations(UserRole role) => isStaff(role);

  static bool canOperateSchedules(UserRole role) {
    return role == UserRole.master ||
        role == UserRole.admin ||
        role == UserRole.member;
  }

  static bool canManageMemberRoles(UserRole role) => role == UserRole.master;

  static bool canTransferGuildMaster(UserRole role) => role == UserRole.master;

  static bool canResetMemberPassword(UserRole role) => isStaff(role);

  static bool canManageGuildSettings(UserRole role) => role == UserRole.master;

  static bool canManageNotices(UserRole role) => isStaff(role);

  static bool canManageCollections(UserRole role) => isStaff(role);

  static bool canManageContentGroups(UserRole role) => isStaff(role);

  static bool canManageSiege(UserRole role) => isStaff(role);

  static bool canManageSupport(UserRole role) => isStaff(role);

  static bool canEditCollectionStatus({
    required UserRole role,
    required int currentUserId,
    required int targetUserId,
  }) {
    return role == UserRole.master || currentUserId == targetUserId;
  }

  static bool canRemoveMember(UserRole role) => role == UserRole.master;
}
