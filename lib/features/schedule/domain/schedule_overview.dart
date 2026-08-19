import 'boss_schedule.dart';

class ScheduleOverview {
  const ScheduleOverview({
    required this.schedules,
    required this.participationTargetBossDefinitionIds,
    required this.participantsByVoteKey,
    required this.closedVoteKeys,
    required this.synchronizedAt,
  });

  final List<BossSchedule> schedules;
  final Set<int> participationTargetBossDefinitionIds;
  final Map<String, List<String>> participantsByVoteKey;
  final Set<String> closedVoteKeys;
  final DateTime synchronizedAt;

  List<String> participantsFor(BossSchedule schedule) {
    return participantsByVoteKey[schedule.voteKey] ?? const <String>[];
  }

  bool isParticipationTarget(BossSchedule schedule) {
    final bossDefinitionId = schedule.bossDefinitionId;
    return bossDefinitionId != null &&
        participationTargetBossDefinitionIds.contains(bossDefinitionId);
  }

  bool canParticipate(BossSchedule schedule) {
    return isParticipationTarget(schedule) &&
        !closedVoteKeys.contains(schedule.voteKey);
  }
}
