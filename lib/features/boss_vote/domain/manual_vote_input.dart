class ManualVoteInput {
  const ManualVoteInput({
    required this.boss,
    required this.spawnTime,
    required this.type,
    required this.region,
    required this.isBlessed,
  });

  final String boss;
  final int spawnTime;
  final String type;
  final String region;
  final bool isBlessed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'boss': boss.trim(),
    'spawnTime': spawnTime,
    'type': type,
    'region': region.trim(),
    'isBlessed': isBlessed,
  };
}
