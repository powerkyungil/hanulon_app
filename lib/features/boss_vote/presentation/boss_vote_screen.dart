import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/time/seoul_datetime.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../characters/presentation/character_target_selector.dart';
import '../application/boss_vote_controller.dart';
import '../domain/manual_vote_input.dart';
import '../domain/vote_boss.dart';
import '../domain/vote_participant.dart';

enum _VoteDay { today, tomorrow, past }

class BossVoteScreen extends ConsumerStatefulWidget {
  const BossVoteScreen({super.key});

  @override
  ConsumerState<BossVoteScreen> createState() => _BossVoteScreenState();
}

class _BossVoteScreenState extends ConsumerState<BossVoteScreen> {
  _VoteDay _selectedDay = _VoteDay.today;
  String? _busyVoteKey;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bossVoteControllerProvider);
    final session = ref.watch(authControllerProvider).value;
    final canManage = RoleGuard.canManageOperations(
      session?.role ?? UserRole.unknown,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('보스 참여 투표'),
        actions: <Widget>[
          if (canManage)
            IconButton(
              onPressed: _showManualVoteSheet,
              tooltip: '수동 투표 추가',
              icon: const Icon(Icons.add_task_outlined),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: isDeputyFeatureForbidden(error) ? '권한 안내' : '문제가 발생했어요',
          message: deputyPermissionMessage(error),
          onRetry: isDeputyCharacterRequired(error)
              ? () => context.push('/deputy/characters')
              : isDeputyFeatureForbidden(error)
              ? null
              : ref.read(bossVoteControllerProvider.notifier).refresh,
          actionLabel: isDeputyCharacterRequired(error) ? '캐릭터 선택' : null,
          onAction: isDeputyCharacterRequired(error)
              ? () => context.push('/deputy/characters')
              : null,
        ),
        data: _buildList,
      ),
    );
  }

  Future<void> _showManualVoteSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: _ManualVoteSheet(
          initialNow: ref.read(serverClockProvider).now(),
          onSubmit: (input) => ref
              .read(bossVoteControllerProvider.notifier)
              .createManualVote(input),
        ),
      ),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('수동 투표를 추가했습니다.')));
  }

  Widget _buildList(List<VoteBoss> allItems) {
    final items = allItems.where(_matchesSelectedDay).toList();
    return RefreshIndicator(
      onRefresh: ref.read(bossVoteControllerProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.floatingNavigationClearance,
        ),
        children: <Widget>[
          SegmentedButton<_VoteDay>(
            segments: const <ButtonSegment<_VoteDay>>[
              ButtonSegment<_VoteDay>(value: _VoteDay.today, label: Text('오늘')),
              ButtonSegment<_VoteDay>(
                value: _VoteDay.tomorrow,
                label: Text('내일'),
              ),
              ButtonSegment<_VoteDay>(
                value: _VoteDay.past,
                label: Text('지난 일정'),
              ),
            ],
            selected: <_VoteDay>{_selectedDay},
            onSelectionChanged: (selection) {
              setState(() => _selectedDay = selection.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.space5),
          const CharacterTargetSelector(),
          const SizedBox(height: AppSpacing.space5),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.space8),
              child: EmptyView(
                title: '해당하는 투표가 없어요',
                message: '일정이 추가되면 이곳에서 참여 여부를 선택할 수 있어요.',
                icon: Icons.how_to_vote_outlined,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                child: _VoteCard(
                  item: item,
                  isBusy: _busyVoteKey == item.voteKey,
                  onShowParticipants: () => _showParticipants(item),
                  onToggle: item.isClosed ? null : () => _toggle(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _matchesSelectedDay(VoteBoss item) {
    final clockNow = ref.read(serverClockProvider).now();
    final today = DateFormat('yyyy-MM-dd').format(
      SeoulDateTime.fromEpochMilliseconds(clockNow.millisecondsSinceEpoch),
    );
    final tomorrow = DateFormat('yyyy-MM-dd').format(
      SeoulDateTime.fromEpochMilliseconds(
        clockNow.add(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
    );
    final itemDate = DateFormat(
      'yyyy-MM-dd',
    ).format(SeoulDateTime.fromEpochMilliseconds(item.spawnTime));
    return switch (_selectedDay) {
      _VoteDay.today => itemDate == today,
      _VoteDay.tomorrow => itemDate == tomorrow,
      _VoteDay.past => itemDate.compareTo(today) < 0,
    };
  }

  Future<void> _toggle(VoteBoss item) async {
    setState(() => _busyVoteKey = item.voteKey);
    try {
      final joined = await ref
          .read(bossVoteControllerProvider.notifier)
          .toggleParticipation(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(joined ? '참여로 표시했습니다.' : '참여를 취소했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      if (isDeputyCharacterRequired(error)) {
        context.push('/deputy/characters');
        return;
      }
      final message = error is ApiException
          ? deputyPermissionMessage(error)
          : '참여 상태를 변경하지 못했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busyVoteKey = null);
    }
  }

  Future<void> _showParticipants(VoteBoss item) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ParticipantsSheet(item: item),
    );
  }
}

class _ParticipantsSheet extends StatelessWidget {
  const _ParticipantsSheet({required this.item});

  final VoteBoss item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final participants = item.participants;

    return FractionallySizedBox(
      key: const ValueKey<String>('vote-participants-sheet'),
      heightFactor: _heightFactor(participants.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.space2,
              AppSpacing.space3,
            ),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.groups_2_outlined, color: scheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${item.boss} 참여자',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        '총 ${participants.length}명',
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          Expanded(
            child: participants.isEmpty
                ? _EmptyParticipants(palette: palette)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 600
                          ? 3
                          : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.space4,
                          AppSpacing.screenHorizontal,
                          AppSpacing.space6,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: AppSpacing.space2,
                          mainAxisSpacing: AppSpacing.space2,
                          mainAxisExtent: 56,
                        ),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          return _ParticipantTile(
                            key: ValueKey<String>(
                              'vote-participant-${item.voteKey}-${participant.characterKey ?? participant.userId}',
                            ),
                            participant: participant,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _heightFactor(int count) {
    if (count == 0) return 0.34;
    if (count <= 4) return 0.46;
    if (count <= 10) return 0.62;
    return 0.76;
  }
}

class _EmptyParticipants extends StatelessWidget {
  const _EmptyParticipants({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space3),
                child: Icon(
                  Icons.person_add_alt_1_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            const Text('아직 참여자가 없어요.', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '첫 참여자가 등록되면 이곳에 표시됩니다.',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, super.key});

  final VoteParticipant participant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final trimmedNickname = participant.targetDisplayName.trim();
    final actor = participant.votedBy;
    final initial = trimmedNickname.isEmpty
        ? '?'
        : trimmedNickname.substring(0, 1);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.primarySoft,
              child: Text(
                initial,
                style: AppTextStyles.label.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '대상 · ${trimmedNickname.isEmpty ? '이름 없음' : trimmedNickname}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actor == null
                        ? '직접 투표'
                        : '대신 투표한 계정 · ${actor.nickname.isEmpty ? actor.label : actor.nickname}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteCard extends StatelessWidget {
  const _VoteCard({
    required this.item,
    required this.isBusy,
    required this.onShowParticipants,
    required this.onToggle,
  });

  final VoteBoss item;
  final bool isBusy;
  final VoidCallback onShowParticipants;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final colors = _tagColors(context, item.type);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space1,
                  children: <Widget>[
                    StatusTag(
                      key: ValueKey<String>('vote-type-${item.voteKey}'),
                      label: item.type,
                      foregroundColor: colors.$1,
                      backgroundColor: colors.$2,
                    ),
                    if (item.isManual)
                      StatusTag(
                        label: '수동',
                        foregroundColor: scheme.primary,
                        backgroundColor: scheme.primary.withValues(alpha: .12),
                      ),
                    if (item.isBlessed) ...<Widget>[
                      StatusTag(
                        label: '축',
                        foregroundColor: palette.warning,
                        backgroundColor: palette.warningSoft,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.joined) ...<Widget>[
                const SizedBox(width: AppSpacing.space2),
                StatusTag(
                  label: '참여',
                  foregroundColor: palette.success,
                  backgroundColor: palette.successSoft,
                  icon: Icons.check_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            item.boss,
            key: ValueKey<String>('vote-boss-${item.voteKey}'),
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            '${SeoulDateTime.formatDateTime(item.spawnTime)} · ${item.region}',
            style: AppTextStyles.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            item.isClosed
                ? '마감된 투표 · ${item.participants.length}명 참여'
                : '현재 ${item.participants.length}명 참여',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: '참여자 보기',
                  variant: AppButtonVariant.secondary,
                  onPressed: onShowParticipants,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: AppButton(
                  label: item.isClosed
                      ? '마감됨'
                      : item.joined
                      ? '참여 취소'
                      : '참여하기',
                  variant: item.joined
                      ? AppButtonVariant.secondary
                      : AppButtonVariant.primary,
                  onPressed: onToggle,
                  isBusy: isBusy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (Color, Color) _tagColors(BuildContext context, String type) {
    final palette = context.appPalette;
    return switch (type) {
      '본섭' => (palette.bossMain, palette.bossMainSoft),
      '침공' => (palette.bossInvasion, palette.bossInvasionSoft),
      '공통' => (palette.bossCommon, palette.bossCommonSoft),
      _ => (palette.bossFixed, palette.bossFixedSoft),
    };
  }
}

class _ManualVoteSheet extends StatefulWidget {
  const _ManualVoteSheet({required this.initialNow, required this.onSubmit});

  final DateTime initialNow;
  final Future<void> Function(ManualVoteInput input) onSubmit;

  @override
  State<_ManualVoteSheet> createState() => _ManualVoteSheetState();
}

class _ManualVoteSheetState extends State<_ManualVoteSheet> {
  static const _types = <String>['공통', '본섭', '침공', '고정'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bossController;
  late final TextEditingController _regionController;
  late DateTime _date;
  late TimeOfDay _time;
  String _type = '공통';
  bool _isBlessed = false;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final seoulNow = SeoulDateTime.fromEpochMilliseconds(
      widget.initialNow.millisecondsSinceEpoch,
    );
    _bossController = TextEditingController();
    _regionController = TextEditingController(text: '공통');
    _date = DateTime(seoulNow.year, seoulNow.month, seoulNow.day);
    _time = TimeOfDay(hour: seoulNow.hour, minute: seoulNow.minute);
  }

  @override
  void dispose() {
    _bossController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('수동 투표 추가'),
        actions: <Widget>[
          IconButton(
            onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
            tooltip: '닫기',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space2,
            AppSpacing.screenHorizontal,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space8,
          ),
          children: <Widget>[
            Text('일정에 없는 보스를 직접 투표 대상으로 추가합니다.', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.space5),
            AppTextField(
              label: '보스명',
              controller: _bossController,
              hintText: '예: 파르바',
              prefixIcon: Icons.flag_outlined,
              maxLength: 40,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '보스명을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text('보스 유형', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.space2),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              items: _types
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: _isBusy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _type = value);
                    },
              validator: (value) => value == null ? '보스 유형을 선택해 주세요.' : null,
            ),
            const SizedBox(height: AppSpacing.space4),
            AppTextField(
              label: '지역',
              controller: _regionController,
              hintText: '예: 요툰하임',
              prefixIcon: Icons.place_outlined,
              maxLength: 30,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '지역을 입력해 주세요.' : null,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text('출현 시각', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.space2),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_formatDate(_date)),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_formatTime(_time)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('축 보스'),
              subtitle: const Text('목록에 축 보스 태그로 표시합니다.'),
              value: _isBlessed,
              onChanged: _isBusy
                  ? null
                  : (value) => setState(() => _isBlessed = value),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space3),
              Text(
                _errorMessage!,
                style: AppTextStyles.label.copyWith(
                  color: context.appPalette.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space5),
            AppButton(
              label: '투표 추가',
              icon: Icons.add_task_outlined,
              expand: true,
              isBusy: _isBusy,
              onPressed: _isBusy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1, 12, 31),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        ManualVoteInput(
          boss: _bossController.text,
          spawnTime: SeoulDateTime.toEpochMilliseconds(
            date: _date,
            time: TimeParts(hour: _time.hour, minute: _time.minute),
          ),
          type: _type,
          region: _regionController.text,
          isBlessed: _isBlessed,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : '수동 투표를 추가하지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _formatDate(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
