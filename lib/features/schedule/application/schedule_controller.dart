import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../characters/application/character_target_controller.dart';
import '../../boss_vote/application/boss_vote_controller.dart';
import '../data/schedule_repository.dart';
import '../domain/boss_schedule.dart';
import '../domain/boss_definition.dart';
import '../domain/schedule_overview.dart';

class ScheduleController extends AsyncNotifier<ScheduleOverview> {
  @override
  Future<ScheduleOverview> build() {
    final session = ref.watch(authControllerProvider).value;
    final selectedKey = ref.watch(selectedCharacterKeyProvider);
    final characterKey = requestedCharacterKey(session, selectedKey);
    final repository = ref.read(scheduleRepositoryProvider);
    if (repository case final CharacterAwareScheduleRepository aware) {
      return aware.fetchOverviewForCharacter(characterKey: characterKey);
    }
    return repository.fetchOverview();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final session = ref.read(authControllerProvider).value;
      final selectedKey = ref.read(selectedCharacterKeyProvider);
      final characterKey = requestedCharacterKey(session, selectedKey);
      final repository = ref.read(scheduleRepositoryProvider);
      if (repository case final CharacterAwareScheduleRepository aware) {
        return aware.fetchOverviewForCharacter(characterKey: characterKey);
      }
      return repository.fetchOverview();
    });
  }

  Future<void> cut(BossSchedule schedule) async {
    await ref.read(scheduleRepositoryProvider).cut(schedule);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> create(BossSchedule schedule) async {
    await ref.read(scheduleRepositoryProvider).createSchedules(<BossSchedule>[
      schedule,
    ]);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> createMany(List<BossSchedule> schedules) async {
    await ref.read(scheduleRepositoryProvider).createSchedules(schedules);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> saveParticipationTargets(Set<int> bossDefinitionIds) async {
    await ref
        .read(scheduleRepositoryProvider)
        .saveParticipationTargets(bossDefinitionIds);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> createBoss(BossDefinition definition) async {
    await ref.read(scheduleRepositoryProvider).createBoss(definition);
    ref.invalidate(bossDefinitionsProvider);
    await refresh();
  }

  Future<void> deleteBoss(int id) async {
    await ref.read(scheduleRepositoryProvider).deleteBoss(id);
    ref.invalidate(bossDefinitionsProvider);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> reorderBosses(List<BossDefinition> definitions) async {
    await ref.read(scheduleRepositoryProvider).reorderBosses(definitions);
    ref.invalidate(bossDefinitionsProvider);
  }

  Future<void> resetBosses() async {
    await ref.read(scheduleRepositoryProvider).resetBosses();
    ref.invalidate(bossDefinitionsProvider);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> mung(BossSchedule schedule) async {
    await ref.read(scheduleRepositoryProvider).mung(schedule);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> deleteSchedule(int id) async {
    await ref.read(scheduleRepositoryProvider).deleteSchedule(id);
    await refresh();
    _invalidateBossVotes();
  }

  Future<void> deleteAll() async {
    await ref.read(scheduleRepositoryProvider).deleteAll();
    await refresh();
    _invalidateBossVotes();
  }

  Future<bool> toggleParticipation(BossSchedule schedule) async {
    final session = ref.read(authControllerProvider).value;
    final selectedKey = ref.read(selectedCharacterKeyProvider);
    final characterKey = requestedCharacterKey(session, selectedKey);
    final repository = ref.read(scheduleRepositoryProvider);
    final joined = switch (repository) {
      final CharacterAwareScheduleRepository aware =>
        await aware.toggleParticipationForCharacter(
          schedule,
          characterKey: characterKey,
        ),
      _ => await repository.toggleParticipation(schedule),
    };
    await refresh();
    return joined;
  }

  void _invalidateBossVotes() {
    ref.invalidate(bossVoteControllerProvider);
  }
}

final scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, ScheduleOverview>(
      ScheduleController.new,
    );
