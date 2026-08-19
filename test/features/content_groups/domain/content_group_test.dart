import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/content_groups/domain/content_group.dart';
import 'package:odin_guild_app/features/members/domain/guild_member.dart';

void main() {
  test('편성·미편성 길드원을 구분하고 전투력 순으로 정렬한다', () {
    final overview = ContentGroupOverview(
      groups: const <ContentGroup>[
        ContentGroup(id: 1, name: '1군', memberIds: <int>[2]),
      ],
      members: <GuildMember>[
        _member(id: 1, name: '토르', power: 120000),
        _member(id: 2, name: '프레이야', power: 150000),
        _member(id: 3, name: '로키', power: 130000),
      ],
      synchronizedAt: DateTime(2026, 8, 11),
    );

    expect(overview.assignedMemberIds, <int>{2});
    expect(
      overview.unassignedMembers.map((member) => member.nickname),
      <String>['로키', '토르'],
    );
    expect(overview.membersFor(overview.groups.single).single.nickname, '프레이야');
  });
}

GuildMember _member({
  required int id,
  required String name,
  required int power,
}) {
  return GuildMember(
    id: id,
    role: UserRole.member,
    nickname: name,
    occupation: '소서리스',
    mainClass: '아크 메이지',
    combatPower: power,
    maxCritRate: 0,
    maxCritResist: 0,
    statusEffectAccuracy: 0,
    equipment: const {},
    activeSkills: const {},
    passiveSkills: const {},
    alternateCharacters: const <AlternateCharacter>[],
  );
}
