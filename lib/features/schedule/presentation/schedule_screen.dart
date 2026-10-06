import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notifications/boss_schedule_voice.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/time/seoul_datetime.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_hero_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../characters/application/character_target_controller.dart';
import '../../characters/presentation/character_target_selector.dart';
import '../application/schedule_alert_service.dart';
import '../application/schedule_controller.dart';
import '../domain/boss_schedule.dart';
import '../domain/schedule_overview.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({
    this.targetBossDefinitionId,
    this.targetSpawnTime,
    super.key,
  });

  final int? targetBossDefinitionId;
  final int? targetSpawnTime;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with WidgetsBindingObserver {
  static const _types = <String>['공통', '본섭', '침공', '고정'];
  static const _compactKey = 'boss_schedule_compact_view';

  final Set<String> _selectedTypes = _types.toSet();
  final Set<String> _playedVoiceKeys = <String>{};
  final Set<String> _sentPushKeys = <String>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _focusScheduleKey = GlobalKey();
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  bool _compactView = false;
  bool _voiceEnabled = true;
  bool _focusScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(scheduleAlertServiceProvider).initialize());
    if (widget.targetBossDefinitionId != null &&
        widget.targetSpawnTime != null) {
      Future<void>.microtask(
        ref.read(scheduleControllerProvider.notifier).refresh,
      );
    }
    _loadPreferences();
    _startTimers();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _compactView = preferences.getBool(_compactKey) ?? false;
      _voiceEnabled =
          preferences.getBool(bossScheduleVoiceEnabledStorageKey) ?? true;
    });
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkAlerts();
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(scheduleControllerProvider.notifier).refresh();
    });
  }

  void _checkAlerts() {
    final overview = ref.read(scheduleControllerProvider).value;
    if (overview == null) return;
    final now = ref.read(serverClockProvider).now().millisecondsSinceEpoch;
    for (final schedule in overview.schedules) {
      final remainingSeconds = ((schedule.spawnTime - now) / 1000).floor();
      for (final target in const <int>[300, 60, 0]) {
        if (remainingSeconds > target || remainingSeconds <= target - 3) {
          continue;
        }
        final bossDefinitionId = schedule.bossDefinitionId;
        if (bossDefinitionId == null) continue;
        final key = '$bossDefinitionId:${schedule.spawnTime}:$target';
        final message = bossScheduleVoiceMessage(
          bossType: schedule.type,
          boss: schedule.boss,
          leadSeconds: target,
        );

        if (_sentPushKeys.add(key)) {
          unawaited(
            ref
                .read(scheduleAlertServiceProvider)
                .showPushAlert(
                  bossDefinitionId: bossDefinitionId,
                  scheduleId: schedule.id,
                  bossType: schedule.type,
                  region: schedule.region,
                  boss: schedule.boss,
                  spawnTime: schedule.spawnTime,
                  leadSeconds: target,
                  message: message,
                ),
          );
        }

        if (_voiceEnabled && _playedVoiceKeys.add(key)) {
          unawaited(ref.read(scheduleAlertServiceProvider).speak(message));
        }
      }
    }
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimers();
      ref.read(scheduleControllerProvider.notifier).refresh();
    } else if (state != AppLifecycleState.resumed) {
      _stopTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewState = ref.watch(scheduleControllerProvider);
    final session = ref.watch(authControllerProvider).value;
    final selectedCharacterKey = ref.watch(selectedCharacterKeyProvider);
    final selectedCharacterName = ref.watch(selectedCharacterNameProvider);
    final targetCharacterKey = displayCharacterKey(
      session,
      selectedCharacterKey,
    );
    final targetNickname = session?.isDeputy == true
        ? session?.activeCharacter?.displayName ?? session?.nickname ?? ''
        : selectedCharacterName ?? session?.nickname ?? '';
    final role = session?.role ?? UserRole.unknown;
    final canOperateSchedules = RoleGuard.canOperateSchedules(role);
    final canManageSchedules = RoleGuard.canManageOperations(role);

    ref.listen(scheduleControllerProvider, (previous, next) {
      final error = next.error;
      if (error is ApiException &&
          error.type == ApiErrorType.unauthorized &&
          context.mounted) {
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('보스 스케줄'),
        actions: <Widget>[
          IconButton(
            tooltip: _voiceEnabled ? '음성 알림 켜짐' : '음성 알림 꺼짐',
            onPressed: _toggleVoice,
            icon: Icon(
              _voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          if (canOperateSchedules)
            IconButton(
              tooltip: '보스 시간 입력',
              onPressed: () => context.push('/schedule/create'),
              icon: const Icon(Icons.add_rounded),
            ),
          if (canManageSchedules)
            PopupMenuButton<String>(
              tooltip: '일정 관리',
              onSelected: (value) {
                if (value == 'clear') _deleteAll();
                if (value == 'voice_test') {
                  ref
                      .read(scheduleAlertServiceProvider)
                      .speak('보스 스케줄 음성 테스트입니다.');
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'voice_test', child: Text('음성 테스트')),
                PopupMenuItem(value: 'clear', child: Text('전체 초기화')),
              ],
            ),
          const SizedBox(width: AppSpacing.space1),
        ],
      ),
      body: overviewState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: isDeputyFeatureForbidden(error) ? '권한 안내' : '문제가 발생했어요',
          message: deputyPermissionMessage(error),
          onRetry: isDeputyCharacterRequired(error)
              ? () => context.go('/deputy/characters')
              : isDeputyFeatureForbidden(error)
              ? null
              : ref.read(scheduleControllerProvider.notifier).refresh,
          actionLabel: isDeputyCharacterRequired(error) ? '캐릭터 선택' : null,
          onAction: isDeputyCharacterRequired(error)
              ? () => context.go('/deputy/characters')
              : null,
        ),
        data: (overview) => _buildScheduleList(
          overview,
          nickname: targetNickname,
          targetUserId: session?.effectiveUserId,
          targetCharacterKey: targetCharacterKey,
          canOperateSchedules: canOperateSchedules,
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(bossScheduleVoiceEnabledStorageKey, enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('음성 알림을 ${enabled ? '켰습니다.' : '껐습니다.'}')),
    );
  }

  Future<void> _toggleCompactView() async {
    setState(() => _compactView = !_compactView);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_compactKey, _compactView);
  }

  Widget _buildScheduleList(
    ScheduleOverview overview, {
    required String nickname,
    required int? targetUserId,
    required String? targetCharacterKey,
    required bool canOperateSchedules,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final now = ref.read(serverClockProvider).now().millisecondsSinceEpoch;
    final allSchedules = _visibleSchedules(
      overview.schedules,
      now,
      applyTypeFilter: false,
    );
    final schedules = _visibleSchedules(overview.schedules, now);
    final nextSchedule = schedules
        .where((item) => item.spawnTime > now)
        .firstOrNull;
    final focusSchedule = _focusSchedule(schedules, nextSchedule);
    final counts = <String, int>{
      for (final type in _types)
        type: allSchedules.where((item) => item.type == type).length,
    };
    _scheduleFocusScroll(focusSchedule);

    return RefreshIndicator(
      onRefresh: ref.read(scheduleControllerProvider.notifier).refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                AppSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppCard(
                    emphasized: true,
                    child: Row(
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.schedule_rounded,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('현재 서버 시간', style: AppTextStyles.caption),
                              Text(
                                DateFormat(
                                  'HH:mm:ss',
                                ).format(ref.read(serverClockProvider).now()),
                                style: AppTextStyles.sectionTitle.copyWith(
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: palette.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('자동 동기화', style: AppTextStyles.caption),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '30초마다 갱신',
                              style: AppTextStyles.caption.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '공유된 목록 ${schedules.length}건',
                          style: AppTextStyles.bodyStrong,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _toggleCompactView,
                        icon: Icon(
                          _compactView
                              ? Icons.view_agenda_outlined
                              : Icons.view_headline_rounded,
                          size: 18,
                        ),
                        label: Text(_compactView ? '상세히' : '간략히'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _types.map((type) {
                        final selected = _selectedTypes.contains(type);
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpacing.space2,
                          ),
                          child: FilterChip(
                            label: Text('$type ${counts[type]}'),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                value
                                    ? _selectedTypes.add(type)
                                    : _selectedTypes.remove(type);
                              });
                            },
                            showCheckmark: false,
                            selectedColor: palette.primarySoft,
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  const CharacterTargetSelector(),
                ],
              ),
            ),
          ),
          if (schedules.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                title: '표시할 일정이 없어요',
                message: canOperateSchedules
                    ? '보스 시간을 입력하거나 표시 유형을 다시 선택해 주세요.'
                    : '표시 유형을 다시 선택하거나 새로고침해 주세요.',
                actionLabel: canOperateSchedules ? '보스 시간 입력' : null,
                onAction: canOperateSchedules
                    ? () => context.push('/schedule/create')
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.space3,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildRows(
                    schedules,
                    overview,
                    now: now,
                    nextSchedule: nextSchedule,
                    focusSchedule: focusSchedule,
                    nickname: nickname,
                    targetUserId: targetUserId,
                    targetCharacterKey: targetCharacterKey,
                    canOperateSchedules: canOperateSchedules,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.floatingNavigationClearance),
          ),
        ],
      ),
    );
  }

  List<BossSchedule> _visibleSchedules(
    List<BossSchedule> source,
    int now, {
    bool applyTypeFilter = true,
  }) {
    final selected = source
        .where((item) => !applyTypeFilter || _selectedTypes.contains(item.type))
        .toList();
    final pastRegular = selected
        .where((item) => item.spawnTime <= now && !item.isFixed)
        .toList();
    final pastFixed =
        selected.where((item) => item.spawnTime <= now && item.isFixed).toList()
          ..sort((a, b) => b.spawnTime.compareTo(a.spawnTime));
    final future = selected.where((item) => item.spawnTime > now).toList();
    return <BossSchedule>[...pastRegular, ...pastFixed.take(1), ...future]
      ..sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
  }

  BossSchedule? _focusSchedule(
    List<BossSchedule> schedules,
    BossSchedule? nextSchedule,
  ) {
    final targetBossDefinitionId = widget.targetBossDefinitionId;
    final targetSpawnTime = widget.targetSpawnTime;
    if (targetBossDefinitionId != null && targetSpawnTime != null) {
      for (final schedule in schedules) {
        if (schedule.bossDefinitionId == targetBossDefinitionId &&
            schedule.spawnTime == targetSpawnTime) {
          return schedule;
        }
      }
    }
    return nextSchedule;
  }

  void _scheduleFocusScroll(BossSchedule? focusSchedule) {
    if (focusSchedule == null || _focusScrollScheduled) return;
    _focusScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focusContext = _focusScheduleKey.currentContext;
      if (focusContext == null) {
        _focusScrollScheduled = false;
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          focusContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  List<Widget> _buildRows(
    List<BossSchedule> schedules,
    ScheduleOverview overview, {
    required int now,
    required BossSchedule? nextSchedule,
    required BossSchedule? focusSchedule,
    required String nickname,
    required int? targetUserId,
    required String? targetCharacterKey,
    required bool canOperateSchedules,
  }) {
    final rows = <Widget>[];
    String? lastDate;
    for (var index = 0; index < schedules.length; index++) {
      final schedule = schedules[index];
      final date = DateFormat(
        'M월 d일 EEEE',
        'ko_KR',
      ).format(SeoulDateTime.fromEpochMilliseconds(schedule.spawnTime));
      if (_compactView && date != lastDate) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, AppSpacing.space3, 4, 10),
            child: Text(date, style: AppTextStyles.label),
          ),
        );
        lastDate = date;
      }
      rows.add(
        _ScheduleCard(
          key: identical(schedule, focusSchedule) ? _focusScheduleKey : null,
          schedule: schedule,
          overview: overview,
          nickname: nickname,
          targetUserId: targetUserId,
          targetCharacterKey: targetCharacterKey,
          now: now,
          compact: _compactView,
          emphasized: identical(schedule, nextSchedule),
          canOperateSchedules: canOperateSchedules,
          onOpen: () => _showActions(
            schedule,
            overview,
            nickname: nickname,
            targetUserId: targetUserId,
            targetCharacterKey: targetCharacterKey,
            canOperateSchedules: canOperateSchedules,
          ),
          onParticipate: () => _participate(schedule),
          onParticipants: () =>
              _showParticipants(schedule, overview.participantsFor(schedule)),
          onCut: () => _cut(schedule),
          onMung: () => _mung(schedule),
          onDelete: () => _deleteSchedule(schedule),
        ),
      );
      if (index < schedules.length - 1) {
        final gap = schedules[index + 1].spawnTime - schedule.spawnTime;
        if (gap >= const Duration(minutes: 30).inMilliseconds) {
          rows.add(_BreakRow(duration: Duration(milliseconds: gap)));
        } else {
          rows.add(const SizedBox(height: AppSpacing.space3));
        }
      }
    }
    return rows;
  }

  Future<void> _participate(BossSchedule schedule) async {
    await _runAction(
      () => ref
          .read(scheduleControllerProvider.notifier)
          .toggleParticipation(schedule),
      '참여로 표시했습니다.',
    );
  }

  Future<void> _cut(BossSchedule schedule) async {
    if (schedule.type == '침공') {
      if (schedule.id != null) {
        await _runAction(
          () => ref
              .read(scheduleControllerProvider.notifier)
              .deleteSchedule(schedule.id!),
          '${schedule.boss} 침공 일정을 종료했습니다.',
        );
      }
      return;
    }
    await _runAction(
      () => ref.read(scheduleControllerProvider.notifier).cut(schedule),
      '${schedule.boss} 컷 확인 · 다음 젠을 예약했습니다.',
    );
  }

  Future<void> _mung(BossSchedule schedule) async {
    await _runAction(
      () => ref.read(scheduleControllerProvider.notifier).mung(schedule),
      '${schedule.boss} 멍 처리 · 다음 젠을 예약했습니다.',
    );
  }

  Future<void> _showActions(
    BossSchedule schedule,
    ScheduleOverview overview, {
    required String nickname,
    required int? targetUserId,
    required String? targetCharacterKey,
    required bool canOperateSchedules,
  }) async {
    final participants = overview.participantsFor(schedule);
    final joined = overview.isJoined(
      schedule,
      nickname: nickname,
      userId: targetUserId,
      characterKey: targetCharacterKey,
    );
    final isTarget = overview.isParticipationTarget(schedule);
    final closed = overview.closedVoteKeys.contains(schedule.voteKey);
    final isPast =
        schedule.spawnTime <=
        ref.read(serverClockProvider).now().millisecondsSinceEpoch;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(schedule.boss, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.space1),
              Text(
                '${schedule.region} · ${SeoulDateTime.formatDateTime(schedule.spawnTime)}',
                style: AppTextStyles.label,
              ),
              if (joined) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                _ParticipantPreview(participants: participants),
              ] else if (isTarget) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                Text(
                  closed
                      ? '참여가 마감된 일정입니다.'
                      : '현재 ${participants.length}명이 참여했습니다.',
                  style: AppTextStyles.body,
                ),
              ],
              const SizedBox(height: AppSpacing.space5),
              if (isTarget && !joined && !closed)
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _participate(schedule);
                  },
                  child: const Text('참여하기'),
                ),
              if (canOperateSchedules && !schedule.isFixed) ...<Widget>[
                if (isTarget && !joined && !closed)
                  const SizedBox(height: AppSpacing.space2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _cut(schedule);
                        },
                        child: Text(schedule.type == '침공' ? '침공 종료' : '컷'),
                      ),
                    ),
                    if (isPast && schedule.type != '침공') ...<Widget>[
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _mung(schedule);
                          },
                          child: const Text('멍'),
                        ),
                      ),
                    ],
                    if (schedule.id != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.space2),
                      IconButton(
                        tooltip: '일정 삭제',
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _deleteSchedule(schedule);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showParticipants(
    BossSchedule schedule,
    List<String> participants,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${schedule.boss} 참여 목록', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.space1),
              Text('총 ${participants.length}명', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.space4),
              _ParticipantPreview(participants: participants),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      if (isDeputyCharacterRequired(error)) {
        context.go('/deputy/characters');
        return;
      }
      final message = deputyPermissionMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _deleteSchedule(BossSchedule schedule) async {
    if (schedule.id == null) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '일정을 삭제할까요?',
      message: '${schedule.boss} 현재 일정만 삭제합니다. 저장된 참여 이력은 유지됩니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirmed) return;
    await _runAction(
      () => ref
          .read(scheduleControllerProvider.notifier)
          .deleteSchedule(schedule.id!),
      '일정을 삭제했습니다.',
    );
  }

  Future<void> _deleteAll() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '모든 일정을 초기화할까요?',
      message: '현재 공유 일정만 모두 삭제합니다. 날짜별 참여 이력과 고정 일정 설정은 유지됩니다.',
      confirmLabel: '전체 초기화',
      destructive: true,
    );
    if (!confirmed) return;
    await _runAction(
      ref.read(scheduleControllerProvider.notifier).deleteAll,
      '현재 일정을 모두 초기화했습니다.',
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.overview,
    required this.nickname,
    required this.targetUserId,
    required this.targetCharacterKey,
    required this.now,
    required this.compact,
    required this.emphasized,
    required this.canOperateSchedules,
    required this.onOpen,
    required this.onParticipate,
    required this.onParticipants,
    required this.onCut,
    required this.onMung,
    required this.onDelete,
    super.key,
  });

  final BossSchedule schedule;
  final ScheduleOverview overview;
  final String nickname;
  final int? targetUserId;
  final String? targetCharacterKey;
  final int now;
  final bool compact;
  final bool emphasized;
  final bool canOperateSchedules;
  final VoidCallback onOpen;
  final VoidCallback onParticipate;
  final VoidCallback onParticipants;
  final VoidCallback onCut;
  final VoidCallback onMung;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final participants = overview.participantsFor(schedule);
    final joined = overview.isJoined(
      schedule,
      nickname: nickname,
      userId: targetUserId,
      characterKey: targetCharacterKey,
    );
    final isTarget = overview.isParticipationTarget(schedule);
    final closed = overview.closedVoteKeys.contains(schedule.voteKey);
    final isPast = schedule.spawnTime <= now;
    final colors = _tagColors(context, schedule.type);
    final remaining = schedule.spawnTime - now;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (emphasized)
          _buildNextHeader(scheme, palette, colors)
        else
          _buildRegularHeader(scheme, palette, colors, isPast),
        SizedBox(
          height: emphasized
              ? AppSpacing.space6
              : compact
              ? AppSpacing.space2
              : AppSpacing.space3,
        ),
        if (emphasized)
          _buildNextDetails(scheme, palette, remaining)
        else
          _buildRegularDetails(scheme, palette, isPast, remaining),
        if (!compact && (isTarget || canOperateSchedules)) ...<Widget>[
          const SizedBox(height: AppSpacing.space3),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (isTarget && joined)
                _SmallAction(
                  label: '참여목록 ${participants.length}',
                  icon: Icons.groups_2_outlined,
                  onPressed: onParticipants,
                )
              else if (isTarget && !closed)
                _SmallAction(
                  label: '참여',
                  icon: Icons.check_circle_outline_rounded,
                  highlighted: true,
                  onPressed: onParticipate,
                )
              else if (isTarget)
                Text('참여마감', style: AppTextStyles.caption),
              if (canOperateSchedules && !schedule.isFixed)
                _SmallAction(
                  label: schedule.type == '침공' ? '종료' : '컷',
                  icon: Icons.done_rounded,
                  onPressed: onCut,
                ),
              if (canOperateSchedules &&
                  isPast &&
                  schedule.type != '침공' &&
                  !schedule.isFixed)
                _SmallAction(
                  label: '멍',
                  icon: Icons.refresh_rounded,
                  onPressed: onMung,
                ),
              if (canOperateSchedules && schedule.id != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '삭제',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ],
      ],
    );

    if (emphasized) {
      return AppHeroCard(
        padding: EdgeInsets.all(
          compact ? AppSpacing.space4 : AppSpacing.space5,
        ),
        onTap: onOpen,
        child: content,
      );
    }
    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.space3 : AppSpacing.space4),
      onTap: onOpen,
      child: content,
    );
  }

  Widget _buildNextHeader(
    ColorScheme scheme,
    AppThemePalette palette,
    (Color, Color) colors,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          key: ValueKey<String>('schedule-next-icon-${schedule.voteKey}'),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(
              alpha: palette.isDark ? 0.2 : 0.12,
            ),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space2),
            child: Icon(Icons.bolt_rounded, size: 18, color: scheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        _buildTypeBadges(palette, colors),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'NEXT',
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyStrong.copyWith(
                color: scheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '가장 가까운 출현 일정',
              textAlign: TextAlign.end,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegularHeader(
    ColorScheme scheme,
    AppThemePalette palette,
    (Color, Color) colors,
    bool isPast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _buildTypeBadges(palette, colors, isPast: isPast)),
        const SizedBox(width: AppSpacing.space2),
        Flexible(
          child: Text(
            _timeLabel(schedule.spawnTime, now),
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyStrong.copyWith(
              color: scheme.onSurface,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBadges(
    AppThemePalette palette,
    (Color, Color) colors, {
    bool isPast = false,
  }) {
    return Wrap(
      spacing: AppSpacing.space1,
      runSpacing: AppSpacing.space1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        StatusTag(
          key: ValueKey<String>('schedule-type-${schedule.voteKey}'),
          label: schedule.type,
          foregroundColor: colors.$1,
          backgroundColor: colors.$2,
        ),
        if (isPast)
          StatusTag(
            label: '지난보스',
            foregroundColor: palette.danger,
            backgroundColor: palette.dangerSoft,
          ),
        if (schedule.isMung)
          StatusTag(
            label: '멍',
            foregroundColor: palette.bossFixed,
            backgroundColor: palette.bossFixedSoft,
          ),
      ],
    );
  }

  Widget _buildNextDetails(
    ColorScheme scheme,
    AppThemePalette palette,
    int remaining,
  ) {
    final countdownColor =
        remaining <= const Duration(minutes: 5).inMilliseconds
        ? palette.warning
        : scheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                schedule.boss,
                key: ValueKey<String>('schedule-boss-${schedule.voteKey}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Flexible(
                    child: Text(
                      compact
                          ? _timeLabel(schedule.spawnTime, now)
                          : '${_timeLabel(schedule.spawnTime, now)} · ${schedule.region}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primary.withValues(
              alpha: palette.isDark ? 0.18 : 0.1,
            ),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space3,
              AppSpacing.space2,
              AppSpacing.space3,
              AppSpacing.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '출현까지',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  _countdownLabel(remaining),
                  style: AppTextStyles.display.copyWith(color: countdownColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegularDetails(
    ColorScheme scheme,
    AppThemePalette palette,
    bool isPast,
    int remaining,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                schedule.boss,
                key: ValueKey<String>('schedule-boss-${schedule.voteKey}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  schedule.region,
                  style: AppTextStyles.label.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isPast && remaining <= const Duration(minutes: 59).inMilliseconds)
          Text(
            _countdownLabel(remaining),
            style: AppTextStyles.countdown.copyWith(
              color: remaining <= const Duration(minutes: 5).inMilliseconds
                  ? palette.warning
                  : scheme.primary,
            ),
          ),
      ],
    );
  }

  static String _timeLabel(int spawnTime, int now) {
    final time = DateFormat(
      'HH:mm',
    ).format(SeoulDateTime.fromEpochMilliseconds(spawnTime));
    if (spawnTime <= now) {
      final elapsed = Duration(milliseconds: now - spawnTime);
      final text = elapsed.inHours > 0
          ? '${elapsed.inHours}시간 ${elapsed.inMinutes.remainder(60)}분'
          : '${elapsed.inMinutes}분';
      return '$time · +$text';
    }
    final nowDate = SeoulDateTime.fromEpochMilliseconds(now);
    final spawnDate = SeoulDateTime.fromEpochMilliseconds(spawnTime);
    final today = DateTime.utc(nowDate.year, nowDate.month, nowDate.day);
    final target = DateTime.utc(spawnDate.year, spawnDate.month, spawnDate.day);
    final days = target.difference(today).inDays;
    if (days == 1) return '내일 $time';
    if (days == 2) return '모레 $time';
    if (days > 2) return '$days일 후 $time';
    return time;
  }

  static String _countdownLabel(int milliseconds) {
    if (milliseconds <= 0) return '출현';
    final duration = Duration(milliseconds: milliseconds);
    return '-${duration.inMinutes.toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  static (Color, Color) _tagColors(BuildContext context, String type) {
    final palette = context.appPalette;
    return switch (type) {
      '본섭' => (palette.bossMain, palette.bossMainSoft),
      '침공' => (palette.bossInvasion, palette.bossInvasionSoft),
      '공통' => (palette.bossCommon, palette.bossCommonSoft),
      _ => (palette.bossFixed, palette.bossFixedSoft),
    };
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: highlighted
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
            ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = duration.inHours > 0
        ? '${duration.inHours}시간 ${duration.inMinutes.remainder(60)}분'
        : '${duration.inMinutes}분';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.coffee_outlined, size: 15),
                const SizedBox(width: 5),
                Text('휴식 시간 $text', style: AppTextStyles.caption),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ParticipantPreview extends StatelessWidget {
  const _ParticipantPreview({required this.participants});

  final List<String> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Text('아직 참여자가 없습니다.', style: AppTextStyles.body);
    }
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: participants
          .map(
            (name) =>
                Chip(label: Text(name), visualDensity: VisualDensity.compact),
          )
          .toList(),
    );
  }
}
