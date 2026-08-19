class BossSchedule {
  const BossSchedule({
    required this.id,
    required this.bossDefinitionId,
    required this.type,
    required this.region,
    required this.boss,
    required this.spawnTime,
    required this.isMung,
    this.isFixed = false,
  });

  final int? id;
  final int? bossDefinitionId;
  final String type;
  final String region;
  final String boss;
  final int spawnTime;
  final bool isMung;
  final bool isFixed;

  BossSchedule withBossDefinitionId(int value) {
    return BossSchedule(
      id: id,
      bossDefinitionId: value,
      type: type,
      region: region,
      boss: boss,
      spawnTime: spawnTime,
      isMung: isMung,
      isFixed: isFixed,
    );
  }

  String get voteKey => '$type|$region|$boss|$spawnTime';
}
