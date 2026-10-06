import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/content_groups/application/content_group_controller.dart';
import 'package:odin_guild_app/features/content_groups/data/content_group_repository.dart';
import 'package:odin_guild_app/features/content_groups/domain/content_group.dart';
import 'package:odin_guild_app/features/members/data/member_repository.dart';
import 'package:odin_guild_app/features/members/domain/guild_member.dart';
import 'package:odin_guild_app/features/members/domain/member_equipment.dart';

void main() {
  test('길드원을 다른 그룹으로 이동하면 영향받은 두 그룹만 저장한다', () async {
    final groupRepository = _FakeContentGroupRepository();
    final container = _container(groupRepository);
    addTearDown(container.dispose);
    await container.read(contentGroupOverviewProvider.future);

    await container
        .read(contentGroupOverviewProvider.notifier)
        .moveMember(7, targetGroupId: 2);

    final overview = container.read(contentGroupOverviewProvider).value!;
    expect(overview.groups.first.memberIds, isEmpty);
    expect(overview.groups.last.memberIds, <int>[7]);
    expect(groupRepository.saved, <String>['1:', '2:7']);
  });

  test('그룹 저장에 실패하면 서버 보상 요청 후 이전 배치로 복구한다', () async {
    final groupRepository = _FakeContentGroupRepository(failGroupIdOnce: 2);
    final container = _container(groupRepository);
    addTearDown(container.dispose);
    await container.read(contentGroupOverviewProvider.future);

    await expectLater(
      container
          .read(contentGroupOverviewProvider.notifier)
          .moveMember(7, targetGroupId: 2),
      throwsStateError,
    );

    final overview = container.read(contentGroupOverviewProvider).value!;
    expect(overview.groups.first.memberIds, <int>[7]);
    expect(overview.groups.last.memberIds, isEmpty);
    expect(groupRepository.saved, <String>['1:', '2:7', '1:7', '2:']);
  });
}

ProviderContainer _container(_FakeContentGroupRepository repository) {
  return ProviderContainer(
    overrides: [
      contentGroupRepositoryProvider.overrideWithValue(repository),
      memberRepositoryProvider.overrideWithValue(_FakeMemberRepository()),
    ],
  );
}

class _FakeContentGroupRepository implements ContentGroupRepository {
  _FakeContentGroupRepository({this.failGroupIdOnce});

  final int? failGroupIdOnce;
  bool _failed = false;
  final List<String> saved = <String>[];

  @override
  Future<List<ContentGroup>> fetchGroups() async => const <ContentGroup>[
    ContentGroup(id: 1, name: '1군', memberIds: <int>[7]),
    ContentGroup(id: 2, name: '2군', memberIds: <int>[]),
  ];

  @override
  Future<void> saveMembers(int groupId, List<int> memberIds) async {
    saved.add('$groupId:${memberIds.join(',')}');
    if (!_failed && groupId == failGroupIdOnce) {
      _failed = true;
      throw StateError('save failed');
    }
  }

  @override
  Future<ContentGroup> createGroup(String name) async {
    return ContentGroup(id: 3, name: name, memberIds: const <int>[]);
  }

  @override
  Future<void> deleteGroup(int groupId) async {}

  @override
  Future<void> renameGroup(int groupId, String name) async {}
}

class _FakeMemberRepository implements MemberRepository {
  @override
  Future<List<GuildMember>> fetchMembers() async => const <GuildMember>[
    GuildMember(
      id: 7,
      role: UserRole.member,
      nickname: '프레이야',
      occupation: '소서리스',
      mainClass: '아크 메이지',
      combatPower: 150000,
      maxCritRate: 0,
      maxCritResist: 0,
      statusEffectAccuracy: 0,
      equipment: <String, MemberEquipment>{},
      activeSkills: <String, String>{},
      passiveSkills: <String, String>{},
      alternateCharacters: <AlternateCharacter>[],
    ),
  ];

  @override
  Future<List<GuildMember>> fetchContentGroupRoster() => fetchMembers();

  @override
  Future<void> changeRole(int memberId, UserRole role) async {}

  @override
  Future<void> transferGuildMaster(int memberId) async {}

  @override
  Future<void> removeMember(int memberId) async {}

  @override
  Future<void> resetPassword(int memberId) async {}
}
