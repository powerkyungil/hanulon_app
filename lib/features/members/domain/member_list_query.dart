import 'guild_member.dart';

enum MemberViewMode {
  character('캐릭터'),
  equipment('장비'),
  skill('스킬');

  const MemberViewMode(this.label);

  final String label;
}

enum MemberSkillGroup {
  active('액티브'),
  passive('패시브');

  const MemberSkillGroup(this.label);

  final String label;
}

enum MemberSkillState {
  all('전체'),
  learned('습득'),
  missing('미습득');

  const MemberSkillState(this.label);

  final String label;
}

class MemberFilters {
  const MemberFilters({
    this.viewMode = MemberViewMode.character,
    this.occupation,
    this.mainClass,
    this.equipmentPart = '무기',
    this.equipmentGrade,
    this.skillGroup = MemberSkillGroup.active,
    this.skillName = '영웅 1',
    this.skillState = MemberSkillState.all,
  });

  final MemberViewMode viewMode;
  final String? occupation;
  final String? mainClass;
  final String equipmentPart;
  final String? equipmentGrade;
  final MemberSkillGroup skillGroup;
  final String skillName;
  final MemberSkillState skillState;

  bool matches(GuildMember member) {
    return switch (viewMode) {
      MemberViewMode.character =>
        (occupation == null || member.occupation == occupation) &&
            (mainClass == null || member.mainClass == mainClass),
      MemberViewMode.equipment => _matchesEquipment(member),
      MemberViewMode.skill => _matchesSkill(member),
    };
  }

  bool _matchesEquipment(GuildMember member) {
    final equipment = member.equipment[equipmentPart];
    if (equipmentGrade == null) return true;
    if (equipmentGrade == 'missing') {
      return equipment == null || equipment.isEmpty;
    }
    return equipment != null &&
        !equipment.isEmpty &&
        equipment.grade == equipmentGrade;
  }

  bool _matchesSkill(GuildMember member) {
    if (skillState == MemberSkillState.all) return true;
    final skills = skillGroup == MemberSkillGroup.active
        ? member.activeSkills
        : member.passiveSkills;
    final level = skills[skillName] ?? 'X';
    return skillState == MemberSkillState.learned ? level != 'X' : level == 'X';
  }
}

enum MemberSortField {
  combatPower('전투력'),
  maxCritRate('치확'),
  maxCritResist('치저'),
  statusEffectAccuracy('상적/충적');

  const MemberSortField(this.label);

  final String label;

  num valueOf(GuildMember member) {
    return switch (this) {
      MemberSortField.combatPower => member.combatPower,
      MemberSortField.maxCritRate => member.maxCritRate,
      MemberSortField.maxCritResist => member.maxCritResist,
      MemberSortField.statusEffectAccuracy => member.statusEffectAccuracy,
    };
  }
}

abstract final class MemberListQuery {
  static List<GuildMember> apply({
    required List<GuildMember> members,
    required String searchText,
    required MemberSortField sortField,
    required bool descending,
    MemberFilters filters = const MemberFilters(),
  }) {
    final query = searchText.trim().toLowerCase();
    final searched = query.isEmpty
        ? List<GuildMember>.from(members)
        : members.where((member) {
            final alternate = member.alternateCharacter;
            return <String>[
              member.nickname,
              member.occupation,
              member.mainClass,
              alternate?.characterName ?? '',
              alternate?.mainClass ?? '',
            ].any((value) => value.toLowerCase().contains(query));
          }).toList();
    final filtered = searched.where(filters.matches).toList();

    filtered.sort((left, right) {
      final leftValue = sortField.valueOf(left);
      final rightValue = sortField.valueOf(right);
      final byValue = descending
          ? rightValue.compareTo(leftValue)
          : leftValue.compareTo(rightValue);
      if (byValue != 0) return byValue;
      return left.nickname.compareTo(right.nickname);
    });
    return filtered;
  }
}
