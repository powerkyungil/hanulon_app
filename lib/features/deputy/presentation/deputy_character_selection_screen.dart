import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../boss_vote/application/boss_vote_controller.dart';
import '../../content_groups/application/content_group_controller.dart';
import '../../schedule/application/schedule_controller.dart';
import '../../support/application/support_controller.dart';
import '../data/deputy_auth_repository.dart';
import '../domain/deputy_character.dart';

final deputyCharactersProvider = FutureProvider<List<DeputyCharacter>>((ref) {
  return ref.watch(deputyAuthRepositoryProvider).fetchCharacters();
});

class DeputyCharacterSelectionScreen extends ConsumerStatefulWidget {
  const DeputyCharacterSelectionScreen({super.key});

  @override
  ConsumerState<DeputyCharacterSelectionScreen> createState() =>
      _DeputyCharacterSelectionScreenState();
}

class _DeputyCharacterSelectionScreenState
    extends ConsumerState<DeputyCharacterSelectionScreen> {
  String? _busyKey;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    if (session == null || !session.isDeputy) {
      return Scaffold(
        body: ErrorView(
          title: '접근할 수 없어요',
          message: '부주 로그인 후 캐릭터를 선택할 수 있습니다.',
          actionLabel: '로그인으로 이동',
          onAction: () => context.go('/login'),
        ),
      );
    }

    final characters = ref.watch(deputyCharactersProvider);
    final palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: session.activeCharacter != null,
        title: const Text('사용할 캐릭터 선택'),
        actions: <Widget>[
          IconButton(
            tooltip: '로그아웃',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: characters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: isDeputyFeatureForbidden(error) ? '권한 안내' : '문제가 발생했어요',
          message: _messageFor(error),
          onRetry: () => ref.invalidate(deputyCharactersProvider),
        ),
        data: (items) => _buildBody(items, session, palette),
      ),
    );
  }

  Widget _buildBody(
    List<DeputyCharacter> characters,
    Session session,
    AppThemePalette palette,
  ) {
    if (characters.isEmpty) {
      return const EmptyView(
        title: '선택 가능한 캐릭터가 없어요',
        message: '길드에 활성 캐릭터가 등록되어 있는지 확인해 주세요.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space5,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      children: <Widget>[
        AppCard(
          emphasized: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${session.nickname.isEmpty ? session.username : session.nickname}님, 어떤 캐릭터로 참여할까요?',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '부주 계정은 선택한 캐릭터의 참여 상태만 변경합니다. 캐릭터 소유자의 운영진 권한은 상속하지 않습니다.',
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        if (_errorMessage != null) ...<Widget>[
          Text(
            _errorMessage!,
            style: AppTextStyles.label.copyWith(color: palette.danger),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        ...characters.map(
          (character) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: _CharacterCard(
              character: character,
              selected: character.characterKey == session.activeCharacterKey,
              isBusy: _busyKey == character.characterKey,
              onTap: () => _select(character),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _select(DeputyCharacter character) async {
    if (_busyKey != null) return;
    setState(() {
      _busyKey = character.characterKey;
      _errorMessage = null;
    });
    try {
      final selected = await ref
          .read(authControllerProvider.notifier)
          .selectDeputyCharacter(character.characterKey);
      if (!mounted) return;
      if (selected == null) {
        setState(() => _errorMessage = '캐릭터 선택을 확인하지 못했습니다. 다시 시도해 주세요.');
        return;
      }
      ref.invalidate(deputyCharactersProvider);
      ref.invalidate(scheduleControllerProvider);
      ref.invalidate(bossVoteControllerProvider);
      ref.invalidate(supportOverviewProvider);
      ref.invalidate(contentGroupOverviewProvider);
      context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  String _messageFor(Object error) {
    if (isDeputyFeatureForbidden(error)) {
      return '부주 계정에 캐릭터 선택 권한이 없습니다.';
    }
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;
    return '캐릭터 정보를 불러오지 못했습니다.';
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.isBusy,
    required this.onTap,
  });

  final DeputyCharacter character;
  final bool selected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return AppCard(
      onTap: isBusy ? null : onTap,
      borderColor: selected ? scheme.primary : null,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? palette.primarySoft : palette.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: SizedBox.square(
              dimension: 48,
              child: Icon(
                character.isAlternate
                    ? Icons.person_add_alt_1_rounded
                    : Icons.person_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        character.displayName,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    StatusTag(
                      label: character.typeLabel,
                      foregroundColor: scheme.primary,
                      backgroundColor: palette.primarySoft,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '${character.ownerNickname} · ${character.mainClass.isEmpty ? '클래스 미입력' : character.mainClass}',
                  style: AppTextStyles.label.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '전투력 ${_formatNumber(character.combatPower)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          isBusy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
        ],
      ),
    );
  }

  static String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(',');
      buffer.write(raw[index]);
    }
    return buffer.toString();
  }
}
