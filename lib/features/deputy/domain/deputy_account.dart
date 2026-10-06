import 'deputy_character.dart';

class DeputyAccount {
  const DeputyAccount({
    required this.id,
    required this.username,
    required this.nickname,
    required this.isActive,
    this.activeCharacter,
    this.activeCharacterKey,
  });

  final int id;
  final String username;
  final String nickname;
  final bool isActive;
  final DeputyCharacter? activeCharacter;
  final String? activeCharacterKey;
}
