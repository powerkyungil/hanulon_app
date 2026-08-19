import '../../auth/domain/alternate_character.dart';
import '../../auth/domain/user_role.dart';
import 'member_equipment.dart';

class GuildMember {
  const GuildMember({
    required this.id,
    required this.role,
    required this.nickname,
    required this.occupation,
    required this.mainClass,
    required this.combatPower,
    required this.maxCritRate,
    required this.maxCritResist,
    required this.statusEffectAccuracy,
    required this.equipment,
    required this.activeSkills,
    required this.passiveSkills,
    required this.alternateCharacters,
  });

  final int id;
  final UserRole role;
  final String nickname;
  final String occupation;
  final String mainClass;
  final int combatPower;
  final double maxCritRate;
  final double maxCritResist;
  final double statusEffectAccuracy;
  final Map<String, MemberEquipment> equipment;
  final Map<String, String> activeSkills;
  final Map<String, String> passiveSkills;
  final List<AlternateCharacter> alternateCharacters;

  String get characterSummary {
    final values = <String>[
      occupation,
      mainClass,
    ].where((value) => value.trim().isNotEmpty).toList();
    return values.isEmpty ? '캐릭터 정보 없음' : values.join(' · ');
  }

  AlternateCharacter? get alternateCharacter => alternateCharacters.firstOrNull;

  int get learnedSkillCount => <String>[
    ...activeSkills.values,
    ...passiveSkills.values,
  ].where((level) => level != 'X').length;

  int get enteredEquipmentCount =>
      equipment.values.where((item) => !item.isEmpty).length;
}
