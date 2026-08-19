import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/time/seoul_datetime.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../application/schedule_controller.dart';
import '../data/schedule_repository.dart';
import '../domain/boss_definition.dart';
import '../domain/boss_schedule.dart';
import '../domain/boss_time_parser.dart';
import '../domain/ocr_result.dart';

enum _InputMode { direct, exact, screenshot }

class ScheduleCreateScreen extends ConsumerStatefulWidget {
  const ScheduleCreateScreen({super.key});

  @override
  ConsumerState<ScheduleCreateScreen> createState() =>
      _ScheduleCreateScreenState();
}

class _ScheduleCreateScreenState extends ConsumerState<ScheduleCreateScreen> {
  final Map<String, TextEditingController> _baseControllers =
      <String, TextEditingController>{};
  final Map<int, TextEditingController> _bossControllers =
      <int, TextEditingController>{};
  _InputMode _mode = _InputMode.direct;
  BossDefinition? _exactDefinition;
  DateTime _exactDate = DateTime.now();
  TimeOfDay _exactTime = TimeOfDay.now();
  Set<int>? _targetBossDefinitionIds;
  String? _errorMessage;
  bool _isBusy = false;
  bool _draftLoaded = false;

  XFile? _screenshot;
  List<OcrTemplate>? _ocrTemplates;
  OcrTemplate? _ocrTemplate;
  OcrAnalysis? _ocrAnalysis;
  List<_OcrCandidate> _ocrCandidates = const <_OcrCandidate>[];
  String _ocrTargetType = '본섭';

  @override
  void dispose() {
    for (final controller in _baseControllers.values) {
      controller.dispose();
    }
    for (final controller in _bossControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _groupKey(BossDefinition definition) =>
      '${definition.type}|${definition.region}';

  void _ensureControllers(List<BossDefinition> definitions) {
    for (final definition in definitions.where((item) => !item.isFixed)) {
      _baseControllers.putIfAbsent(
        _groupKey(definition),
        TextEditingController.new,
      );
      _bossControllers.putIfAbsent(definition.id, TextEditingController.new);
    }
    if (!_draftLoaded) {
      _draftLoaded = true;
      unawaited(_loadDraft(definitions));
    }
  }

  String get _draftKey {
    final now = DateTime.now();
    return 'boss_schedule_draft_${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadDraft(List<BossDefinition> definitions) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_draftKey);
    if (encoded == null) return;
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final bases =
          json['bases'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final bosses =
          json['bosses'] as Map<String, dynamic>? ?? <String, dynamic>{};
      for (final entry in bases.entries) {
        _baseControllers[entry.key]?.text = entry.value.toString();
      }
      for (final definition in definitions) {
        _bossControllers[definition.id]?.text =
            bosses[definition.id.toString()]?.toString() ?? '';
      }
      if (mounted) setState(() {});
    } catch (_) {
      // A malformed local draft is ignored; server data remains untouched.
    }
  }

  Future<void> _saveDraft() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _draftKey,
      jsonEncode(<String, dynamic>{
        'bases': _baseControllers.map(
          (key, value) => MapEntry<String, String>(key, value.text),
        ),
        'bosses': _bossControllers.map(
          (key, value) => MapEntry<String, String>(key.toString(), value.text),
        ),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final definitionsState = ref.watch(bossDefinitionsProvider);
    final session = ref.watch(authControllerProvider).value;
    final overview = ref.watch(scheduleControllerProvider).value;
    final role = session?.role ?? UserRole.unknown;
    final isMaster = role == UserRole.master;
    final canManageScheduleSettings = RoleGuard.canManageOperations(role);
    if (_targetBossDefinitionIds == null && overview != null) {
      _targetBossDefinitionIds = overview.participationTargetBossDefinitionIds
          .toSet();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('보스 시간 입력'),
        actions: <Widget>[
          if (canManageScheduleSettings)
            PopupMenuButton<String>(
              tooltip: '보스 관리',
              onSelected: (value) {
                definitionsState.whenData((definitions) {
                  if (value == 'add') _showAddBoss(definitions);
                  if (value == 'manage') _showBossList(definitions);
                });
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'add', child: Text('새 보스 추가')),
                PopupMenuItem(value: 'manage', child: Text('보스 목록 관리')),
              ],
            ),
        ],
      ),
      body: definitionsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : '보스 목록을 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(bossDefinitionsProvider),
        ),
        data: (definitions) {
          _ensureControllers(definitions);
          final modes = <ButtonSegment<_InputMode>>[
            const ButtonSegment(
              value: _InputMode.direct,
              icon: Icon(Icons.calculate_outlined),
              label: Text('직접 입력'),
            ),
            const ButtonSegment(
              value: _InputMode.exact,
              icon: Icon(Icons.event_outlined),
              label: Text('한 건'),
            ),
            if (isMaster)
              const ButtonSegment(
                value: _InputMode.screenshot,
                icon: Icon(Icons.image_search_outlined),
                label: Text('스크린샷'),
              ),
          ];
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.space2,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space3,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_InputMode>(
                    segments: modes,
                    selected: <_InputMode>{_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _mode = selection.first);
                      if (selection.first == _InputMode.screenshot) {
                        _loadOcrTemplates();
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: switch (_mode) {
                  _InputMode.direct => _buildDirectInput(
                    definitions,
                    canManageScheduleSettings: canManageScheduleSettings,
                  ),
                  _InputMode.exact => _buildExactInput(definitions),
                  _InputMode.screenshot => _buildScreenshotInput(definitions),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDirectInput(
    List<BossDefinition> definitions, {
    required bool canManageScheduleSettings,
  }) {
    final groups = <String, List<BossDefinition>>{};
    for (final definition in definitions.where((item) => !item.isFixed)) {
      groups
          .putIfAbsent(_groupKey(definition), () => <BossDefinition>[])
          .add(definition);
    }
    final groupsByType =
        <String, List<MapEntry<String, List<BossDefinition>>>>{};
    for (final entry in groups.entries) {
      groupsByType
          .putIfAbsent(
            entry.value.first.type,
            () => <MapEntry<String, List<BossDefinition>>>[],
          )
          .add(entry);
    }
    const typeOrder = <String>['공통', '본섭', '침공'];
    final types = groupsByType.keys.toList()
      ..sort((a, b) {
        final aIndex = typeOrder.indexOf(a);
        final bIndex = typeOrder.indexOf(b);
        final aOrder = aIndex == -1 ? typeOrder.length : aIndex;
        final bOrder = bIndex == -1 ? typeOrder.length : bIndex;
        return aOrder == bOrder ? a.compareTo(b) : aOrder.compareTo(bOrder);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space1,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      children: <Widget>[
        Text(
          '게임의 기준 시각과 보스별 남은 시간을 입력하세요. 기준 시각을 비우면 현재 서버 시간을 사용합니다.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          '예: 2410 = 24분 10초 · 013020 = 1시간 30분 20초',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.space5),
        ...types.map((type) {
          final entries = groupsByType[type]!
            ..sort(
              (a, b) => a.value.first.region.compareTo(b.value.first.region),
            );
          final bossCount = entries.fold<int>(
            0,
            (count, entry) => count + entry.value.length,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _buildTypeTag(type),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '${entries.length}개 지역 · $bossCount개 보스',
                      style: AppTextStyles.label.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space2),
                ...entries.map((entry) {
                  final first = entry.value.first;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          first.region,
                          style: AppTextStyles.cardTitle,
                        ),
                        subtitle: Text(
                          '${entry.value.length}개 보스 · 기준 시각과 남은 시간 입력',
                          style: AppTextStyles.caption,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.space4,
                          0,
                          AppSpacing.space4,
                          AppSpacing.space4,
                        ),
                        children: <Widget>[
                          TextField(
                            controller: _baseControllers[entry.key],
                            keyboardType: TextInputType.datetime,
                            decoration: const InputDecoration(
                              labelText: '기준 시각',
                              hintText: '예: 11:34:01 · 비우면 현재 시각',
                            ),
                            onChanged: (_) => unawaited(_saveDraft()),
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          ...entry.value.map(
                            (definition) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.space2,
                              ),
                              child: TextField(
                                controller: _bossControllers[definition.id],
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: definition.boss,
                                  hintText: '2410 또는 10분 20초',
                                ),
                                onChanged: (_) => unawaited(_saveDraft()),
                                onSubmitted: (_) => _submitDirect(
                                  definitions,
                                  groupKey: entry.key,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space1),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => _submitDirect(
                                      definitions,
                                      groupKey: entry.key,
                                    ),
                              child: const Text('이 지역만 적용'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        if (canManageScheduleSettings) _buildParticipationSettings(definitions),
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          Text(
            _errorMessage!,
            style: AppTextStyles.label.copyWith(
              color: context.appPalette.danger,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space5),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : () => _submitDirect(definitions),
            icon: _isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('입력한 일정 전체 적용'),
          ),
        ),
      ],
    );
  }

  StatusTag _buildTypeTag(String type) {
    final palette = context.appPalette;
    return switch (type) {
      '본섭' => StatusTag(
        label: type,
        foregroundColor: palette.bossMain,
        backgroundColor: palette.bossMainSoft,
      ),
      '침공' => StatusTag(
        label: type,
        foregroundColor: palette.bossInvasion,
        backgroundColor: palette.bossInvasionSoft,
      ),
      '공통' => StatusTag(
        label: type,
        foregroundColor: palette.bossCommon,
        backgroundColor: palette.bossCommonSoft,
      ),
      _ => StatusTag(
        label: type,
        foregroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: palette.primarySoft,
      ),
    };
  }

  Widget _buildParticipationSettings(List<BossDefinition> definitions) {
    final targets = _targetBossDefinitionIds ?? <int>{};
    final bossesByType = <String, List<BossDefinition>>{};
    for (final definition in definitions.where((item) => !item.isFixed)) {
      bossesByType
          .putIfAbsent(definition.type, () => <BossDefinition>[])
          .add(definition);
    }
    const typeOrder = <String>['본섭', '침공', '공통'];
    final types = bossesByType.keys.toList()
      ..sort((a, b) {
        final aIndex = typeOrder.indexOf(a);
        final bIndex = typeOrder.indexOf(b);
        final aOrder = aIndex == -1 ? typeOrder.length : aIndex;
        final bOrder = bIndex == -1 ? typeOrder.length : bIndex;
        return aOrder == bOrder ? a.compareTo(b) : aOrder.compareTo(bOrder);
      });
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space2),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.how_to_reg_outlined),
          title: Text('참여 보스 설정', style: AppTextStyles.cardTitle),
          subtitle: Text(
            '본섭·침공 보스를 따로 선택해 참여 기능을 표시합니다.',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space4,
          ),
          children: <Widget>[
            ...List<Widget>.generate(types.length, (index) {
              final type = types[index];
              final bosses = bossesByType[type]!
                ..sort((a, b) => a.label.compareTo(b.label));
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == types.length - 1 ? 0 : AppSpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(type, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.space2),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columnCount = constraints.maxWidth >= 600 ? 3 : 2;
                        final chipWidth =
                            (constraints.maxWidth -
                                AppSpacing.space2 * (columnCount - 1)) /
                            columnCount;
                        return Wrap(
                          spacing: AppSpacing.space2,
                          runSpacing: AppSpacing.space2,
                          children: bosses.map((definition) {
                            return SizedBox(
                              key: ValueKey<String>(
                                'participation-target-${definition.id}',
                              ),
                              width: chipWidth,
                              child: FilterChip(
                                label: Text(
                                  definition.boss,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                tooltip: definition.boss,
                                selected: targets.contains(definition.id),
                                onSelected: (selected) {
                                  setState(() {
                                    selected
                                        ? targets.add(definition.id)
                                        : targets.remove(definition.id);
                                    _targetBossDefinitionIds = targets;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isBusy ? null : _saveParticipationTargets,
                child: const Text('참여 보스 설정 적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDirect(
    List<BossDefinition> definitions, {
    String? groupKey,
  }) async {
    final schedules = <BossSchedule>[];
    final invalidBosses = <String>[];
    var excludedInvasion = 0;
    final now = ref.read(serverClockProvider).now().millisecondsSinceEpoch;
    final seoulNow = SeoulDateTime.fromEpochMilliseconds(now);
    final tonight = DateTime.utc(
      seoulNow.year,
      seoulNow.month,
      seoulNow.day,
      14,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    for (final entry in _baseControllers.entries) {
      if (groupKey != null && entry.key != groupKey) continue;
      final definitionsInGroup = definitions.where(
        (item) => !item.isFixed && _groupKey(item) == entry.key,
      );
      final baseTime = _parseBaseTime(entry.value.text, now);
      if (baseTime == null) {
        setState(
          () => _errorMessage = '${entry.key.split('|').last} 기준 시각을 확인해 주세요.',
        );
        return;
      }
      for (final definition in definitionsInGroup) {
        final controller = _bossControllers[definition.id]!;
        if (controller.text.trim().isEmpty) continue;
        final remaining = BossTimeParser.parseRemaining(controller.text);
        if (remaining == null) {
          invalidBosses.add(definition.boss);
          continue;
        }
        final spawnTime = baseTime + remaining.inMilliseconds;
        if (definition.type == '침공' && spawnTime > tonight) {
          excludedInvasion++;
          continue;
        }
        schedules.add(
          BossSchedule(
            id: null,
            bossDefinitionId: definition.id,
            type: definition.type,
            region: definition.region,
            boss: definition.boss,
            spawnTime: spawnTime,
            isMung: false,
          ),
        );
      }
    }

    if (invalidBosses.isNotEmpty) {
      setState(
        () => _errorMessage = '${invalidBosses.join(', ')} 남은 시간 형식을 확인해 주세요.',
      );
      return;
    }
    if (schedules.isEmpty) {
      setState(() {
        _errorMessage = excludedInvasion > 0
            ? '오늘 자정을 넘는 침공 일정은 등록 대상에서 제외됩니다.'
            : '등록할 보스의 남은 시간을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await ref.read(scheduleControllerProvider.notifier).createMany(schedules);
      for (final schedule in schedules) {
        final definitionId = schedule.bossDefinitionId;
        if (definitionId != null) {
          _bossControllers[definitionId]?.clear();
        }
      }
      for (final entry in _baseControllers.entries) {
        if (groupKey == null || entry.key == groupKey) {
          final hasRemaining = definitions.any(
            (definition) =>
                _groupKey(definition) == entry.key &&
                (_bossControllers[definition.id]?.text.isNotEmpty ?? false),
          );
          if (!hasRemaining) entry.value.clear();
        }
      }
      await _saveDraft();
      if (!mounted) return;
      final suffix = excludedInvasion > 0
          ? ' · 자정 이후 침공 $excludedInvasion건 제외'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보스 일정 ${schedules.length}건을 등록했습니다.$suffix')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : '일정을 등록하지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  int? _parseBaseTime(String input, int fallback) {
    if (input.trim().isEmpty) return fallback;
    final clock = BossTimeParser.parseClock(input);
    if (clock == null) return null;
    final seoulNow = SeoulDateTime.fromEpochMilliseconds(fallback);
    return DateTime.utc(
      seoulNow.year,
      seoulNow.month,
      seoulNow.day,
      clock.hour - 9,
      clock.minute,
      clock.second,
    ).millisecondsSinceEpoch;
  }

  Future<void> _saveParticipationTargets() async {
    setState(() => _isBusy = true);
    try {
      await ref
          .read(scheduleControllerProvider.notifier)
          .saveParticipationTargets(_targetBossDefinitionIds ?? <int>{});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참여 보스 설정을 적용했습니다.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : '설정을 저장하지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildExactInput(List<BossDefinition> definitions) {
    final selectable = definitions.where((item) => !item.isFixed).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      children: <Widget>[
        Text('출현 시각을 정확히 알고 있는 일정 한 건을 빠르게 등록합니다.', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.space5),
        DropdownButtonFormField<BossDefinition>(
          initialValue: _exactDefinition,
          isExpanded: true,
          hint: const Text('보스를 선택해 주세요'),
          decoration: const InputDecoration(labelText: '보스'),
          items: selectable
              .map(
                (item) => DropdownMenuItem<BossDefinition>(
                  value: item,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _exactDefinition = value),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text('출현 시각', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.space2),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickExactDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_exactDate.month}월 ${_exactDate.day}일'),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickExactTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(_exactTime.format(context)),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.space4),
          Text(
            _errorMessage!,
            style: AppTextStyles.label.copyWith(
              color: context.appPalette.danger,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space6),
        FilledButton(
          onPressed: _isBusy ? null : _submitExact,
          child: const Text('일정 등록'),
        ),
      ],
    );
  }

  Future<void> _pickExactDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _exactDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _exactDate = picked);
  }

  Future<void> _pickExactTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _exactTime,
    );
    if (picked != null) setState(() => _exactTime = picked);
  }

  Future<void> _submitExact() async {
    final definition = _exactDefinition;
    if (definition == null) {
      setState(() => _errorMessage = '등록할 보스를 선택해 주세요.');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(scheduleControllerProvider.notifier)
          .create(
            BossSchedule(
              id: null,
              bossDefinitionId: definition.id,
              type: definition.type,
              region: definition.region,
              boss: definition.boss,
              spawnTime: SeoulDateTime.toEpochMilliseconds(
                date: _exactDate,
                time: TimeParts(
                  hour: _exactTime.hour,
                  minute: _exactTime.minute,
                ),
              ),
              isMung: false,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 등록했습니다.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : '일정을 등록하지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildScreenshotInput(List<BossDefinition> definitions) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      children: <Widget>[
        Text('보스 시간표 스크린샷', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.space2),
        Text(
          '시간표가 모두 보이는 이미지를 선택하면 OCR 권장 크기로 줄여 분석합니다. 결과 확인 전에는 일정이 저장되지 않습니다.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.space5),
        AppCard(
          onTap: _pickScreenshot,
          child: Column(
            children: <Widget>[
              Icon(
                _screenshot == null
                    ? Icons.add_photo_alternate_outlined
                    : Icons.image_outlined,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                _screenshot?.name ?? '스크린샷 선택',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong,
              ),
              const SizedBox(height: 3),
              Text(
                'PNG, JPG, WEBP · 긴 변 1960px로 최적화',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        DropdownButtonFormField<OcrTemplate>(
          initialValue: _ocrTemplate,
          decoration: const InputDecoration(labelText: '스크린샷 템플릿'),
          hint: Text(_ocrTemplates == null ? '템플릿 불러오는 중' : '템플릿 선택'),
          items: (_ocrTemplates ?? const <OcrTemplate>[])
              .map(
                (template) => DropdownMenuItem(
                  value: template,
                  child: Text(template.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _ocrTemplate = value),
        ),
        const SizedBox(height: AppSpacing.space4),
        FilledButton.icon(
          onPressed: _isBusy || _screenshot == null || _ocrTemplate == null
              ? null
              : () => _analyzeScreenshot(definitions),
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(_isBusy ? 'OCR 분석 중' : '스크린샷 분석'),
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
        if (_ocrAnalysis != null) ...<Widget>[
          const SizedBox(height: AppSpacing.space6),
          Text(
            '인식 결과 ${_ocrAnalysis!.fields.length}개',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.space3),
          ..._ocrAnalysis!.fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(field.name, style: AppTextStyles.label),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Flexible(
                      child: Text(field.text, style: AppTextStyles.bodyStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '등록 대상 ${_ocrCandidates.length}건',
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: AppSpacing.space2),
          if (_ocrCandidates.isEmpty)
            Text('등록 가능한 보스명과 남은 시간을 찾지 못했습니다.', style: AppTextStyles.body)
          else ...<Widget>[
            ..._ocrCandidates.map(
              (candidate) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(candidate.boss),
                trailing: Text(_durationLabel(candidate.remaining)),
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: '본섭', label: Text('본섭')),
                ButtonSegment(value: '침공', label: Text('침공')),
              ],
              selected: <String>{_ocrTargetType},
              onSelectionChanged: (value) {
                setState(() => _ocrTargetType = value.first);
              },
            ),
            const SizedBox(height: AppSpacing.space3),
            FilledButton(
              onPressed: _isBusy
                  ? null
                  : () => _registerOcrCandidates(definitions),
              child: const Text('확인 후 스케줄 등록'),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _loadOcrTemplates() async {
    if (_ocrTemplates != null) return;
    try {
      final templates = await ref
          .read(scheduleRepositoryProvider)
          .fetchOcrTemplates();
      if (!mounted) return;
      setState(() => _ocrTemplates = templates);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ocrTemplates = const <OcrTemplate>[];
        _errorMessage = error is ApiException
            ? error.message
            : 'OCR 템플릿을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1960,
      maxHeight: 1960,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _screenshot = picked;
      _ocrAnalysis = null;
      _ocrCandidates = const <_OcrCandidate>[];
      _errorMessage = null;
    });
  }

  Future<void> _analyzeScreenshot(List<BossDefinition> definitions) async {
    final screenshot = _screenshot;
    final template = _ocrTemplate;
    if (screenshot == null || template == null) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final analysis = await ref
          .read(scheduleRepositoryProvider)
          .analyzeScreenshot(
            bytes: await screenshot.readAsBytes(),
            templateId: template.id,
            contentType: screenshot.mimeType ?? 'image/jpeg',
          );
      final now = ref.read(serverClockProvider).now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() {
        _ocrAnalysis = analysis;
        _ocrCandidates = _extractOcrCandidates(analysis, definitions, now);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'OCR 분석에 실패했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  List<_OcrCandidate> _extractOcrCandidates(
    OcrAnalysis analysis,
    List<BossDefinition> definitions,
    int now,
  ) {
    var reference = now;
    for (final field in analysis.fields) {
      final match = RegExp(
        r'(\d{1,2}):(\d{2})(?::(\d{2}))?',
      ).firstMatch(field.text);
      if (match == null) continue;
      final clock = BossTimeParser.parseClock(match.group(0)!);
      if (clock == null) continue;
      final seoulNow = SeoulDateTime.fromEpochMilliseconds(now);
      reference = DateTime.utc(
        seoulNow.year,
        seoulNow.month,
        seoulNow.day,
        clock.hour - 9,
        clock.minute,
        clock.second,
      ).millisecondsSinceEpoch;
      if (reference - now > const Duration(hours: 12).inMilliseconds) {
        reference -= const Duration(days: 1).inMilliseconds;
      } else if (now - reference > const Duration(hours: 12).inMilliseconds) {
        reference += const Duration(days: 1).inMilliseconds;
      }
      break;
    }

    const aliases = <String, List<String>>{
      '4층분노의모네가름': <String>['분노의 모네가름'],
      '7층나태의드라우그': <String>['나태의 드라우그'],
      '10층다인홀로크': <String>['기만의 기사 다인홀로크'],
      '최하층강글': <String>['광란의 사제 강글로티'],
      '최하층굴베': <String>['광란의 굴베이그', '광란의 마수 굴베이그'],
      '최하층스네르': <String>['광란의 상속자 스네르', '광란의 참수자 스네르'],
    };
    final bosses = definitions
        .where((item) => !item.isFixed)
        .map((item) => item.boss)
        .toSet();
    final candidates = <String, _OcrCandidate>{};
    for (final field in analysis.fields) {
      final normalized = _normalizeOcr(field.text);
      for (final boss in bosses) {
        final names = <String>[boss, ...?aliases[boss]];
        for (final name in names) {
          final normalizedName = _normalizeOcr(name);
          final index = normalized.indexOf(normalizedName);
          if (index < 0) continue;
          final tail = normalized.substring(index + normalizedName.length);
          final appearing = tail.contains('출현중') || tail.contains('출연중');
          final remaining = appearing ? Duration.zero : _findDuration(tail);
          if (remaining == null) continue;
          candidates[boss] = _OcrCandidate(
            boss: boss,
            remaining: remaining,
            spawnTime: reference + remaining.inMilliseconds,
          );
          break;
        }
      }
    }
    return candidates.values.toList()
      ..sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
  }

  String _normalizeOcr(String value) =>
      value.replaceAll(RegExp(r'[\s·ㆍ,./-]'), '');

  Duration? _findDuration(String value) {
    final match = RegExp(
      r'(?:(\d+)일)?(?:(\d+)시간)?(?:(\d+)분)?(?:(\d+)초)?',
    ).allMatches(value).where((item) => item.group(0)!.isNotEmpty).firstOrNull;
    if (match == null) return null;
    return BossTimeParser.parseRemaining(match.group(0)!);
  }

  String _durationLabel(Duration duration) {
    if (duration == Duration.zero) return '현재 출현';
    final parts = <String>[
      if (duration.inDays > 0) '${duration.inDays}일',
      if (duration.inHours.remainder(24) > 0)
        '${duration.inHours.remainder(24)}시간',
      if (duration.inMinutes.remainder(60) > 0)
        '${duration.inMinutes.remainder(60)}분',
      if (duration.inSeconds.remainder(60) > 0)
        '${duration.inSeconds.remainder(60)}초',
    ];
    return '${parts.join(' ')} 후';
  }

  Future<void> _registerOcrCandidates(List<BossDefinition> definitions) async {
    final schedules = <String, BossSchedule>{};
    for (final candidate in _ocrCandidates) {
      final common = definitions.where(
        (item) => item.type == '공통' && item.boss == candidate.boss,
      );
      final target = definitions.where(
        (item) => item.type == _ocrTargetType && item.boss == candidate.boss,
      );
      final definition = common.isNotEmpty
          ? common.first
          : target.isNotEmpty
          ? target.first
          : null;
      if (definition == null) continue;
      schedules['${definition.type}|${definition.region}|${definition.boss}'] =
          BossSchedule(
            id: null,
            bossDefinitionId: definition.id,
            type: definition.type,
            region: definition.region,
            boss: definition.boss,
            spawnTime: candidate.spawnTime,
            isMung: false,
          );
    }
    if (schedules.isEmpty) {
      setState(() => _errorMessage = '$_ocrTargetType 목록에서 등록할 보스를 찾지 못했습니다.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      await ref
          .read(scheduleControllerProvider.notifier)
          .createMany(schedules.values.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR 일정 ${schedules.length}건을 등록했습니다.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'OCR 일정을 등록하지 못했습니다.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showAddBoss(List<BossDefinition> definitions) async {
    final definition = await showModalBottomSheet<BossDefinition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddBossSheet(),
    );
    if (definition == null) return;
    try {
      await ref
          .read(scheduleControllerProvider.notifier)
          .createBoss(definition);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 보스를 추가했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : '보스를 추가하지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _showBossList(List<BossDefinition> definitions) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BossListSheet(
        definitions: definitions,
        onDelete: (id) =>
            ref.read(scheduleControllerProvider.notifier).deleteBoss(id),
        onReorder: (items) =>
            ref.read(scheduleControllerProvider.notifier).reorderBosses(items),
        onReset: ref.read(scheduleControllerProvider.notifier).resetBosses,
      ),
    );
  }
}

class _BossListSheet extends StatefulWidget {
  const _BossListSheet({
    required this.definitions,
    required this.onDelete,
    required this.onReorder,
    required this.onReset,
  });

  final List<BossDefinition> definitions;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function(List<BossDefinition> definitions) onReorder;
  final Future<void> Function() onReset;

  @override
  State<_BossListSheet> createState() => _BossListSheetState();
}

class _BossListSheetState extends State<_BossListSheet> {
  late final List<BossDefinition> _definitions = widget.definitions.toList();
  bool _dirty = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Text('보스 목록 관리', style: AppTextStyles.sectionTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space1,
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
              ),
              child: Text(
                '오른쪽 손잡이를 끌어 입력 화면의 보스 순서를 바꿀 수 있습니다.',
                style: AppTextStyles.caption,
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                itemCount: _definitions.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _definitions.removeAt(oldIndex);
                    _definitions.insert(newIndex, item);
                    _dirty = true;
                  });
                },
                itemBuilder: (_, index) {
                  final definition = _definitions[index];
                  return ListTile(
                    key: ValueKey<int>(definition.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(definition.boss),
                    subtitle: Text(definition.label),
                    leading: IconButton(
                      tooltip: '보스 삭제',
                      onPressed: _busy ? null : () => _delete(definition),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('기본값 복구'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || !_dirty ? null : _saveOrder,
                      child: const Text('순서 저장'),
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

  Future<void> _delete(BossDefinition definition) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${definition.boss} 보스를 삭제할까요?',
      message: '보스 정의와 현재 스케줄이 함께 삭제됩니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await widget.onDelete(definition.id);
    if (!mounted) return;
    setState(() {
      _definitions.remove(definition);
      _busy = false;
    });
  }

  Future<void> _saveOrder() async {
    setState(() => _busy = true);
    await widget.onReorder(_definitions);
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _busy = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('보스 나열 순서를 저장했습니다.')));
  }

  Future<void> _reset() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '기본 보스 목록으로 초기화할까요?',
      message: '커스텀 보스와 모든 현재 스케줄이 삭제되고 기본 목록으로 복구됩니다.',
      confirmLabel: '초기화',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await widget.onReset();
    if (mounted) Navigator.of(context).pop();
  }
}

class _AddBossSheet extends StatefulWidget {
  const _AddBossSheet();

  @override
  State<_AddBossSheet> createState() => _AddBossSheetState();
}

class _AddBossSheetState extends State<_AddBossSheet> {
  final _bossController = TextEditingController();
  final _typeController = TextEditingController(text: '본섭');
  final _regionController = TextEditingController();
  final _cooldownController = TextEditingController();
  final _timeController = TextEditingController();
  final Set<String> _days = <String>{'월', '화', '수', '목', '금', '토', '일'};
  bool _fixed = false;

  @override
  void dispose() {
    _bossController.dispose();
    _typeController.dispose();
    _regionController.dispose();
    _cooldownController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space5,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('새 보스 추가', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.space4),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment(value: false, label: Text('일반 보스')),
                  ButtonSegment(value: true, label: Text('고정 일정')),
                ],
                selected: <bool>{_fixed},
                onSelectionChanged: (value) {
                  setState(() => _fixed = value.first);
                },
              ),
              const SizedBox(height: AppSpacing.space4),
              TextField(
                controller: _bossController,
                decoration: const InputDecoration(labelText: '보스 이름'),
              ),
              const SizedBox(height: AppSpacing.space3),
              if (!_fixed) ...<Widget>[
                TextField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: '분류',
                    hintText: '본섭, 침공, 공통',
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                TextField(
                  controller: _regionController,
                  decoration: const InputDecoration(labelText: '지역'),
                ),
                const SizedBox(height: AppSpacing.space3),
                TextField(
                  controller: _cooldownController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '쿨타임(시간)'),
                ),
              ] else ...<Widget>[
                TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '등장 시각',
                    hintText: '21:30:00',
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Wrap(
                  spacing: AppSpacing.space2,
                  children: const <String>['월', '화', '수', '목', '금', '토', '일']
                      .map(
                        (day) => FilterChip(
                          label: Text(day),
                          selected: _days.contains(day),
                          onSelected: (selected) {
                            setState(() {
                              selected ? _days.add(day) : _days.remove(day);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.space5),
              FilledButton(onPressed: _submit, child: const Text('보스 추가')),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final boss = _bossController.text.trim();
    if (boss.isEmpty) return;
    if (_fixed && BossTimeParser.parseClock(_timeController.text) == null) {
      return;
    }
    if (!_fixed &&
        (_typeController.text.trim().isEmpty ||
            _regionController.text.trim().isEmpty)) {
      return;
    }
    Navigator.of(context).pop(
      BossDefinition(
        id: 0,
        type: _fixed ? '고정' : _typeController.text.trim(),
        region: _fixed ? '공통' : _regionController.text.trim(),
        boss: boss,
        cooldownHours: _fixed
            ? 0
            : double.tryParse(_cooldownController.text) ?? 0,
        timeText: _fixed ? _timeController.text.trim() : null,
        days: _fixed ? _days.toList() : const <String>[],
      ),
    );
  }
}

class _OcrCandidate {
  const _OcrCandidate({
    required this.boss,
    required this.remaining,
    required this.spawnTime,
  });

  final String boss;
  final Duration remaining;
  final int spawnTime;
}
