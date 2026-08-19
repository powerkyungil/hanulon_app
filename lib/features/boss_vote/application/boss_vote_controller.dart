import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/boss_vote_repository.dart';
import '../domain/manual_vote_input.dart';
import '../domain/vote_boss.dart';

class BossVoteController extends AsyncNotifier<List<VoteBoss>> {
  @override
  Future<List<VoteBoss>> build() {
    return ref.read(bossVoteRepositoryProvider).fetchVoteBosses();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      ref.read(bossVoteRepositoryProvider).fetchVoteBosses,
    );
  }

  Future<void> createManualVote(ManualVoteInput input) async {
    await ref.read(bossVoteRepositoryProvider).createManualVote(input);
    await refresh();
  }

  Future<bool> toggleParticipation(VoteBoss voteBoss) async {
    final joined = await ref
        .read(bossVoteRepositoryProvider)
        .toggleParticipation(voteBoss);
    await refresh();
    return joined;
  }
}

final bossVoteControllerProvider =
    AsyncNotifierProvider<BossVoteController, List<VoteBoss>>(
      BossVoteController.new,
    );
