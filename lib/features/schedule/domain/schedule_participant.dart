class ScheduleParticipant {
  const ScheduleParticipant({
    required this.userId,
    required this.nickname,
    this.characterType,
    this.characterKey,
    this.characterName,
  });

  final int? userId;
  final String nickname;
  final String? characterType;
  final String? characterKey;
  final String? characterName;

  String get displayName {
    final name = characterName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    if (characterType?.toUpperCase() == 'ALTERNATE') return '$nickname의 부캐';
    return nickname;
  }
}
