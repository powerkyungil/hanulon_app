import 'vote_participant.dart';

class VoteBoss {
  const VoteBoss({
    required this.id,
    required this.voteKey,
    required this.type,
    required this.region,
    required this.boss,
    required this.spawnTime,
    required this.participants,
    required this.joined,
    required this.isClosed,
    required this.isBlessed,
    required this.isManual,
    required this.isHistory,
  });

  final int? id;
  final String voteKey;
  final String type;
  final String region;
  final String boss;
  final int spawnTime;
  final List<VoteParticipant> participants;
  final bool joined;
  final bool isClosed;
  final bool isBlessed;
  final bool isManual;
  final bool isHistory;
}
