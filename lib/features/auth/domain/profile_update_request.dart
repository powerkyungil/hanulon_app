import 'alternate_character.dart';

class ProfileUpdateRequest {
  const ProfileUpdateRequest({
    required this.nickname,
    required this.occupation,
    required this.mainClass,
    required this.combatPower,
    required this.equipment,
    required this.skills,
    required this.maxCritRate,
    required this.maxCritResist,
    required this.statusEffectAccuracy,
    required this.alternateCharacters,
    this.password,
  });

  final String nickname;
  final String occupation;
  final String mainClass;
  final int combatPower;
  final Map<String, dynamic> equipment;
  final Map<String, dynamic> skills;
  final double maxCritRate;
  final double maxCritResist;
  final double statusEffectAccuracy;
  final List<AlternateCharacter> alternateCharacters;
  final String? password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nickname': nickname,
      'occupation': occupation,
      'main_class': mainClass,
      'combat_power': combatPower,
      'equipment': equipment,
      'skills': skills,
      'max_crit_rate': maxCritRate,
      'max_crit_resist': maxCritResist,
      'status_effect_acc': statusEffectAccuracy,
      'alternate_characters': alternateCharacters
          .map((character) => character.toJson())
          .toList(),
      if (password != null && password!.isNotEmpty) 'password': password,
    };
  }
}
