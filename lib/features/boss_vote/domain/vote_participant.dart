class VoteParticipant {
  const VoteParticipant({
    required this.userId,
    required this.nickname,
    this.characterType,
    this.characterKey,
    this.characterName,
    this.votedBy,
  });

  final int userId;
  final String nickname;
  final String? characterType;
  final String? characterKey;
  final String? characterName;
  final VoteActor? votedBy;

  bool get isAlternate => characterType?.toUpperCase() == 'ALTERNATE';

  String get targetDisplayName {
    final name = characterName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    if (isAlternate) {
      final key = characterKey?.trim() ?? '';
      return key.isEmpty ? '$nickname의 부캐' : '$nickname의 부캐 ($key)';
    }
    return nickname;
  }
}

class VoteActor {
  const VoteActor({
    required this.accountType,
    required this.accountId,
    required this.nickname,
  });

  final String accountType;
  final int? accountId;
  final String nickname;

  bool get isDeputy => accountType.toUpperCase() == 'DEPUTY';

  String get label => isDeputy ? '부주 계정' : '길드 계정';
}
