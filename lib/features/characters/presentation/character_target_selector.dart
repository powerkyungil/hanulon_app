import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../boss_vote/application/boss_vote_controller.dart';
import '../../members/application/members_controller.dart';
import '../../members/domain/guild_member.dart';
import '../../schedule/application/schedule_controller.dart';
import '../application/character_target_controller.dart';

class GuildCharacterTarget {
  const GuildCharacterTarget({
    required this.characterKey,
    required this.characterType,
    required this.ownerUserId,
    required this.ownerNickname,
    required this.characterName,
    required this.mainClass,
    required this.combatPower,
  });

  final String characterKey;
  final String characterType;
  final int ownerUserId;
  final String ownerNickname;
  final String characterName;
  final String mainClass;
  final int combatPower;

  bool get isAlternate => characterType == 'ALTERNATE';

  String get typeLabel => isAlternate ? '부캐' : '본캐';

  String get displayName => characterName.trim().isEmpty
      ? ownerNickname.trim().isEmpty
            ? '이름 없는 캐릭터'
            : ownerNickname
      : characterName;

  static List<GuildCharacterTarget> fromMembers(List<GuildMember> members) {
    final result = <GuildCharacterTarget>[];
    for (final member in members) {
      result.add(
        GuildCharacterTarget(
          characterKey: 'MAIN:${member.id}',
          characterType: 'MAIN',
          ownerUserId: member.id,
          ownerNickname: member.nickname,
          characterName: member.nickname,
          mainClass: member.mainClass,
          combatPower: member.combatPower,
        ),
      );
      final alternate = member.alternateCharacter;
      if (alternate != null) {
        result.add(
          GuildCharacterTarget(
            characterKey: 'ALTERNATE:${member.id}',
            characterType: 'ALTERNATE',
            ownerUserId: member.id,
            ownerNickname: member.nickname,
            characterName: alternate.characterName,
            mainClass: alternate.mainClass,
            combatPower: member.combatPower,
          ),
        );
      }
    }
    return result;
  }
}

class CharacterTargetSelector extends ConsumerWidget {
  const CharacterTargetSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    if (session == null) return const SizedBox.shrink();
    final selectedKey = ref.watch(selectedCharacterKeyProvider);
    final targetKey = displayCharacterKey(session, selectedKey);
    final deputyTarget = session.activeCharacter;
    final label = session.isDeputy
        ? deputyTarget?.displayName ?? '캐릭터를 선택해 주세요'
        : targetKey == 'MAIN:${session.userId}'
        ? session.nickname
        : '선택한 캐릭터';
    final detail = session.isDeputy
        ? deputyTarget == null
              ? '선택 전에는 참여 기능을 사용할 수 없습니다.'
              : '${deputyTarget.ownerNickname} · ${deputyTarget.typeLabel}'
        : targetKey == 'MAIN:${session.userId}'
        ? '본캐 기준'
        : '대리 대상 · $targetKey';

    return AppCard(
      key: const ValueKey<String>('character-target-selector'),
      onTap: () => session.isDeputy
          ? context.push('/deputy/characters')
          : _showMemberCharacterSheet(context, ref, session),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appPalette.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Icon(
                Icons.person_search_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('참여 캐릭터', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.space1),
                Text(label, style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberCharacterSheet(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    try {
      final members = await ref.read(membersControllerProvider.future);
      if (!context.mounted) return;
      final targets = GuildCharacterTarget.fromMembers(members);
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CharacterTargetSheet(
          targets: targets,
          selectedKey: displayCharacterKey(
            session,
            ref.read(selectedCharacterKeyProvider),
          ),
          onSelected: (target) {
            final ownMainKey = 'MAIN:${session.userId}';
            ref.read(selectedCharacterKeyProvider.notifier).state =
                target.characterKey == ownMainKey ? null : target.characterKey;
            ref.read(selectedCharacterNameProvider.notifier).state =
                target.characterKey == ownMainKey ? null : target.displayName;
            ref.invalidate(scheduleControllerProvider);
            ref.invalidate(bossVoteControllerProvider);
            Navigator.of(context).pop();
          },
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('길드원 캐릭터 목록을 불러오지 못했습니다.')));
    }
  }
}

class _CharacterTargetSheet extends StatelessWidget {
  const _CharacterTargetSheet({
    required this.targets,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<GuildCharacterTarget> targets;
  final String? selectedKey;
  final ValueChanged<GuildCharacterTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.space2,
            ),
            child: Text('대상 캐릭터 선택', style: AppTextStyles.sectionTitle),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.space4,
            ),
            child: Text(
              '선택한 캐릭터 기준으로 일정 참여와 투표 상태를 보여줍니다.',
              style: AppTextStyles.label,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.space6,
              ),
              itemCount: targets.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.space2),
              itemBuilder: (context, index) {
                final target = targets[index];
                final selected = target.characterKey == selectedKey;
                return ListTile(
                  minTileHeight: 64,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: selected
                      ? context.appPalette.primarySoft
                      : context.appPalette.surfaceSubtle,
                  leading: Icon(
                    target.isAlternate
                        ? Icons.person_add_alt_1_outlined
                        : Icons.person_outline_rounded,
                  ),
                  title: Text(target.displayName),
                  subtitle: Text(
                    '${target.ownerNickname} · ${target.typeLabel} · ${target.mainClass}',
                  ),
                  trailing: selected ? const Icon(Icons.check_rounded) : null,
                  onTap: () => onSelected(target),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
