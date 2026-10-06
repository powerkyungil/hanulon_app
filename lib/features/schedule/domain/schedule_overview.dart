import 'boss_schedule.dart';
import 'schedule_participant.dart';

class ScheduleOverview {
  const ScheduleOverview({
    required this.schedules,
    required this.participationTargetBossDefinitionIds,
    required this.participantsByVoteKey,
    required this.closedVoteKeys,
    required this.synchronizedAt,
    this.participantDetailsByVoteKey =
        const <String, List<ScheduleParticipant>>{},
  });

  final List<BossSchedule> schedules;
  final Set<int> participationTargetBossDefinitionIds;
  final Map<String, List<String>> participantsByVoteKey;
  final Set<String> closedVoteKeys;
  final DateTime synchronizedAt;
  final Map<String, List<ScheduleParticipant>> participantDetailsByVoteKey;

  List<String> participantsFor(BossSchedule schedule) {
    return participantsByVoteKey[schedule.voteKey] ?? const <String>[];
  }

  List<ScheduleParticipant> participantDetailsFor(BossSchedule schedule) {
    return participantDetailsByVoteKey[schedule.voteKey] ??
        const <ScheduleParticipant>[];
  }

  bool isJoined(
    BossSchedule schedule, {
    String? nickname,
    int? userId,
    String? characterKey,
  }) {
    final details = participantDetailsFor(schedule);
    if (characterKey != null && characterKey.isNotEmpty) {
      if (details.any((item) => item.characterKey == characterKey)) return true;
      final isMain = characterKey.startsWith('MAIN:');
      if (isMain &&
          details.any(
            (item) =>
                item.characterKey == null &&
                userId != null &&
                item.userId == userId,
          )) {
        return true;
      }
    }
    if (nickname != null && participantsFor(schedule).contains(nickname)) {
      return true;
    }
    return false;
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
