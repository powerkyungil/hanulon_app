import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/permissions/role_guard.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';

void main() {
  group('RoleGuard', () {
    test('길드장과 운영진은 운영 기능을 관리할 수 있다', () {
      expect(RoleGuard.canManageOperations(UserRole.master), isTrue);
      expect(RoleGuard.canManageOperations(UserRole.admin), isTrue);
    });

    test('일반 길드원은 운영 기능을 관리할 수 없다', () {
      expect(RoleGuard.canManageOperations(UserRole.member), isFalse);
    });

    test('부주 계정은 참여 기능만 사용하고 운영 기능은 관리할 수 없다', () {
      expect(RoleGuard.isDeputy(UserRole.deputy), isTrue);
      expect(RoleGuard.canViewSchedules(UserRole.deputy), isTrue);
      expect(RoleGuard.canParticipateSchedules(UserRole.deputy), isTrue);
      expect(RoleGuard.canUseSupport(UserRole.deputy), isTrue);
      expect(RoleGuard.canManageOperations(UserRole.deputy), isFalse);
      expect(RoleGuard.canManageContentGroups(UserRole.deputy), isFalse);
      expect(RoleGuard.canManageDeputyAccounts(UserRole.deputy), isFalse);
    });

    test('모든 활성 길드원은 보스 일정을 등록하고 처리할 수 있다', () {
      expect(RoleGuard.canOperateSchedules(UserRole.master), isTrue);
      expect(RoleGuard.canOperateSchedules(UserRole.admin), isTrue);
      expect(RoleGuard.canOperateSchedules(UserRole.member), isTrue);
      expect(RoleGuard.canOperateSchedules(UserRole.unknown), isFalse);
    });

    test('길드원 강퇴는 길드장만 가능하다', () {
      expect(RoleGuard.canRemoveMember(UserRole.master), isTrue);
      expect(RoleGuard.canRemoveMember(UserRole.admin), isFalse);
    });

    test('역할 변경은 서버 정책에 따라 길드장만 가능하다', () {
      expect(RoleGuard.canManageMemberRoles(UserRole.master), isTrue);
      expect(RoleGuard.canManageMemberRoles(UserRole.admin), isFalse);
    });

    test('길드장 위임은 현재 길드장만 가능하다', () {
      expect(RoleGuard.canTransferGuildMaster(UserRole.master), isTrue);
      expect(RoleGuard.canTransferGuildMaster(UserRole.admin), isFalse);
      expect(RoleGuard.canTransferGuildMaster(UserRole.member), isFalse);
    });

    test('길드장과 운영진은 비밀번호를 초기화할 수 있다', () {
      expect(RoleGuard.canResetMemberPassword(UserRole.master), isTrue);
      expect(RoleGuard.canResetMemberPassword(UserRole.admin), isTrue);
      expect(RoleGuard.canResetMemberPassword(UserRole.member), isFalse);
    });

    test('마스터 설정은 길드장만 관리할 수 있다', () {
      expect(RoleGuard.canManageGuildSettings(UserRole.master), isTrue);
      expect(RoleGuard.canManageGuildSettings(UserRole.admin), isFalse);
      expect(RoleGuard.canManageGuildSettings(UserRole.member), isFalse);
    });

    test('공지 관리는 길드장과 운영진만 사용할 수 있다', () {
      expect(RoleGuard.canManageNotices(UserRole.master), isTrue);
      expect(RoleGuard.canManageNotices(UserRole.admin), isTrue);
      expect(RoleGuard.canManageNotices(UserRole.member), isFalse);
    });

    test('컬렉션 정의는 운영진이 관리하고 타인 체크는 길드장만 변경한다', () {
      expect(RoleGuard.canManageCollections(UserRole.master), isTrue);
      expect(RoleGuard.canManageCollections(UserRole.admin), isTrue);
      expect(RoleGuard.canManageCollections(UserRole.member), isFalse);
      expect(
        RoleGuard.canEditCollectionStatus(
          role: UserRole.admin,
          currentUserId: 7,
          targetUserId: 7,
        ),
        isTrue,
      );
      expect(
        RoleGuard.canEditCollectionStatus(
          role: UserRole.admin,
          currentUserId: 7,
          targetUserId: 8,
        ),
        isFalse,
      );
      expect(
        RoleGuard.canEditCollectionStatus(
          role: UserRole.master,
          currentUserId: 7,
          targetUserId: 8,
        ),
        isTrue,
      );
    });

    test('콘텐츠 그룹 편성은 길드장과 운영진만 관리한다', () {
      expect(RoleGuard.canManageContentGroups(UserRole.master), isTrue);
      expect(RoleGuard.canManageContentGroups(UserRole.admin), isTrue);
      expect(RoleGuard.canManageContentGroups(UserRole.member), isFalse);
    });

    test('공성전 전체 현황 관리는 길드장과 운영진만 가능하다', () {
      expect(RoleGuard.canManageSiege(UserRole.master), isTrue);
      expect(RoleGuard.canManageSiege(UserRole.admin), isTrue);
      expect(RoleGuard.canManageSiege(UserRole.member), isFalse);
    });

    test('손지원 전체 요청 관리는 길드장과 운영진만 가능하다', () {
      expect(RoleGuard.canManageSupport(UserRole.master), isTrue);
      expect(RoleGuard.canManageSupport(UserRole.admin), isTrue);
      expect(RoleGuard.canManageSupport(UserRole.member), isFalse);
    });
  });
}
