import 'registration_mode.dart';

class RegistrationRequest {
  const RegistrationRequest({
    required this.mode,
    this.inviteCode = '',
    this.guildName = '',
    required this.username,
    required this.password,
    required this.nickname,
    required this.occupation,
    required this.mainClass,
    required this.combatPower,
    required this.equipment,
    required this.skills,
  });

  final RegistrationMode mode;
  final String inviteCode;
  final String guildName;
  final String username;
  final String password;
  final String nickname;
  final String occupation;
  final String mainClass;
  final int combatPower;
  final Map<String, dynamic> equipment;
  final Map<String, dynamic> skills;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode.apiValue,
      if (mode == RegistrationMode.joinGuild && inviteCode.trim().isNotEmpty)
        'code': inviteCode.trim(),
      if (mode == RegistrationMode.createGuild && guildName.trim().isNotEmpty)
        'guild_name': guildName.trim(),
      'username': username,
      'password': password,
      'nickname': nickname,
      'occupation': occupation,
      'main_class': mainClass,
      'combat_power': combatPower,
      'equipment': equipment,
      'skills': skills,
    };
  }
}
