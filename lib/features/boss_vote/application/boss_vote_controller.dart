import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../characters/application/character_target_controller.dart';
import '../data/boss_vote_repository.dart';
import '../domain/manual_vote_input.dart';
import '../domain/vote_boss.dart';

class BossVoteController extends AsyncNotifier<List<VoteBoss>> {
  @override
  Future<List<VoteBoss>> build() {
    final session = ref.watch(authControllerProvider).value;
    final selectedKey = ref.watch(selectedCharacterKeyProvider);
    final characterKey = requestedCharacterKey(session, selectedKey);
    final repository = ref.read(bossVoteRepositoryProvider);
    if (repository case final CharacterAwareBossVoteRepository aware) {
      return aware.fetchVoteBossesForCharacter(characterKey: characterKey);
    }
    return repository.fetchVoteBosses();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final session = ref.read(authControllerProvider).value;
      final selectedKey = ref.read(selectedCharacterKeyProvider);
      final characterKey = requestedCharacterKey(session, selectedKey);
      final repository = ref.read(bossVoteRepositoryProvider);
      if (repository case final CharacterAwareBossVoteRepository aware) {
        return aware.fetchVoteBossesForCharacter(characterKey: characterKey);
      }
      return repository.fetchVoteBosses();
    });
  }

  Future<void> createManualVote(ManualVoteInput input) async {
    await ref.read(bossVoteRepositoryProvider).createManualVote(input);
    await refresh();
  }

  Future<bool> toggleParticipation(VoteBoss voteBoss) async {
    final session = ref.read(authControllerProvider).value;
    final selectedKey = ref.read(selectedCharacterKeyProvider);
    final characterKey = requestedCharacterKey(session, selectedKey);
    final repository = ref.read(bossVoteRepositoryProvider);
    final joined = switch (repository) {
      final CharacterAwareBossVoteRepository aware =>
        await aware.toggleParticipationForCharacter(
          voteBoss,
          characterKey: characterKey,
        ),
      _ => await repository.toggleParticipation(voteBoss),
    };
    await refresh();
    return joined;
  }
}

final bossVoteControllerProvider =
    AsyncNotifierProvider<BossVoteController, List<VoteBoss>>(
      BossVoteController.new,
    );
