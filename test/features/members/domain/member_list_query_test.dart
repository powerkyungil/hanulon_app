import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/members/domain/guild_member.dart';
import 'package:odin_guild_app/features/members/domain/member_list_query.dart';
import 'package:odin_guild_app/features/members/domain/member_equipment.dart';

void main() {
  final members = <GuildMember>[
    _member(
      id: 1,
      nickname: '프레이야',
      occupation: '소서리스',
      mainClass: '아크 메이지',
      combatPower: 120000,
      maxCritRate: 51.2,
      equipment: const <String, MemberEquipment>{
        '무기': MemberEquipment(value: '발뭉', grade: 'legend'),
      },
      activeSkills: const <String, String>{'영웅 1': '8강'},
    ),
    _member(
      id: 2,
      nickname: '토르',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 140000,
      maxCritRate: 42.5,
      alternate: const AlternateCharacter(
        characterName: '망치왕',
        mainClass: '팔라딘',
      ),
      equipment: const <String, MemberEquipment>{
        '무기': MemberEquipment(value: '영웅 검', grade: 'hero'),
      },
      activeSkills: const <String, String>{'영웅 1': 'X'},
    ),
  ];

  test('기본 전투력 높은 순으로 길드원을 정렬한다', () {
    final result = MemberListQuery.apply(
      members: members,
      searchText: '',
      sortField: MemberSortField.combatPower,
      descending: true,
    );

    expect(result.map((member) => member.nickname), <String>['토르', '프레이야']);
  });

  test('주캐릭터와 부계정 이름 및 클래스까지 검색한다', () {
    final byOccupation = MemberListQuery.apply(
      members: members,
      searchText: '소서리스',
      sortField: MemberSortField.combatPower,
      descending: true,
    );
    final byAlternate = MemberListQuery.apply(
      members: members,
      searchText: '망치왕',
      sortField: MemberSortField.combatPower,
      descending: true,
    );

    expect(byOccupation.single.nickname, '프레이야');
    expect(byAlternate.single.nickname, '토르');
  });

  test('치명타 확률 낮은 순 정렬을 적용한다', () {
    final result = MemberListQuery.apply(
      members: members,
      searchText: '',
      sortField: MemberSortField.maxCritRate,
      descending: false,
    );

    expect(result.map((member) => member.nickname), <String>['토르', '프레이야']);
  });

  test('캐릭터 직업과 주클래스 필터를 함께 적용한다', () {
    final result = MemberListQuery.apply(
      members: members,
      searchText: '',
      sortField: MemberSortField.combatPower,
      descending: true,
      filters: const MemberFilters(occupation: '소서리스', mainClass: '아크 메이지'),
    );

    expect(result.single.nickname, '프레이야');
  });

  test('선택한 장비 부위와 등급으로 길드원을 필터링한다', () {
    final result = MemberListQuery.apply(
      members: members,
      searchText: '',
      sortField: MemberSortField.combatPower,
      descending: true,
      filters: const MemberFilters(
        viewMode: MemberViewMode.equipment,
        equipmentPart: '무기',
        equipmentGrade: 'hero',
      ),
    );

    expect(result.single.nickname, '토르');
  });

  test('선택한 액티브 스킬의 습득 여부로 길드원을 필터링한다', () {
    final result = MemberListQuery.apply(
      members: members,
      searchText: '',
      sortField: MemberSortField.combatPower,
      descending: true,
      filters: const MemberFilters(
        viewMode: MemberViewMode.skill,
        skillGroup: MemberSkillGroup.active,
        skillName: '영웅 1',
        skillState: MemberSkillState.learned,
      ),
    );

    expect(result.single.nickname, '프레이야');
  });
}

GuildMember _member({
  required int id,
  required String nickname,
  required String occupation,
  required String mainClass,
  required int combatPower,
  required double maxCritRate,
  AlternateCharacter? alternate,
  Map<String, MemberEquipment> equipment = const <String, MemberEquipment>{},
  Map<String, String> activeSkills = const <String, String>{},
}) {
  return GuildMember(
    id: id,
    role: UserRole.member,
    nickname: nickname,
    occupation: occupation,
    mainClass: mainClass,
    combatPower: combatPower,
    maxCritRate: maxCritRate,
    maxCritResist: 0,
    statusEffectAccuracy: 0,
    equipment: equipment,
    activeSkills: activeSkills,
    passiveSkills: const {},
    alternateCharacters: alternate == null
        ? const <AlternateCharacter>[]
        : <AlternateCharacter>[alternate],
  );
}
