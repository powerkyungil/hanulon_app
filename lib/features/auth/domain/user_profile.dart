import 'alternate_character.dart';
import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.nickname,
    this.username,
    this.occupation,
    this.mainClass,
    this.combatPower,
    this.equipment = const <String, dynamic>{},
    this.skills = const <String, dynamic>{},
    this.maxCritRate = 0,
    this.maxCritResist = 0,
    this.statusEffectAccuracy = 0,
    this.alternateCharacters = const <AlternateCharacter>[],
  });

  final int id;
  final UserRole role;
  final String nickname;
  final String? username;
  final String? occupation;
  final String? mainClass;
  final int? combatPower;
  final Map<String, dynamic> equipment;
  final Map<String, dynamic> skills;
  final double maxCritRate;
  final double maxCritResist;
  final double statusEffectAccuracy;
  final List<AlternateCharacter> alternateCharacters;
}
