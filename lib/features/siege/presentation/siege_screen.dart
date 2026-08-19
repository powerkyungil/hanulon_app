import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../application/siege_controller.dart';
import '../domain/siege_record.dart';

enum _SiegeEntryFilter { all, entered, missing }

class SiegeScreen extends ConsumerStatefulWidget {
  const SiegeScreen({super.key});

  @override
  ConsumerState<SiegeScreen> createState() => _SiegeScreenState();
}

class _SiegeScreenState extends ConsumerState<SiegeScreen> {
  final _searchController = TextEditingController();
  _SiegeEntryFilter _filter = _SiegeEntryFilter.all;
  final Set<int> _editingIds = <int>{};
  bool _isResetting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(siegeOverviewProvider);
    final session = ref.watch(authControllerProvider).value;
    final currentUserId = session?.userId ?? 0;
    final role = session?.role ?? UserRole.unknown;
    final canManage = RoleGuard.canManageSiege(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공성전 현황'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                ref.read(siegeOverviewProvider.notifier).refreshOverview(),
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canManage)
            IconButton(
              onPressed: _isResetting ? null : _resetAll,
              tooltip: '공성전 데이터 전체 초기화',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: _messageFor(error),
          onRetry: () => ref.invalidate(siegeOverviewProvider),
        ),
        data: (overview) => _buildBody(
          overview,
          currentUserId: currentUserId,
          canManage: canManage,
        ),
      ),
    );
  }

  Widget _buildBody(
    SiegeOverview overview, {
    required int currentUserId,
    required bool canManage,
  }) {
    final currentRecord = overview.recordFor(currentUserId);
    final records = _filteredRecords(overview.records);
    final enteredCount = overview.enteredCount;
    final missingCount = overview.records.length - enteredCount;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(siegeOverviewProvider.notifier).refreshOverview(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space2,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                _SiegeSummaryCard(overview: overview),
                const SizedBox(height: AppSpacing.space4),
                if (currentRecord != null)
                  _MySiegeInputCard(
                    record: currentRecord,
                    onSave: (input) => ref
                        .read(siegeOverviewProvider.notifier)
                        .saveMine(input),
                  )
                else
                  const EmptyView(
                    title: '내 길드원 정보를 찾을 수 없어요',
                    message: '목록을 새로고침하거나 운영진에게 문의해 주세요.',
                  ),
                const SizedBox(height: AppSpacing.space6),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('길드원 현황', style: AppTextStyles.sectionTitle),
                    ),
                    Text('${records.length}명', style: AppTextStyles.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '길드원 닉네임 또는 클래스 검색',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_SiegeEntryFilter>(
                    segments: <ButtonSegment<_SiegeEntryFilter>>[
                      ButtonSegment<_SiegeEntryFilter>(
                        value: _SiegeEntryFilter.all,
                        label: Text('전체 ${overview.records.length}'),
                      ),
                      ButtonSegment<_SiegeEntryFilter>(
                        value: _SiegeEntryFilter.entered,
                        label: Text('입력 $enteredCount'),
                      ),
                      ButtonSegment<_SiegeEntryFilter>(
                        value: _SiegeEntryFilter.missing,
                        label: Text('미입력 $missingCount'),
                      ),
                    ],
                    selected: <_SiegeEntryFilter>{_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _filter = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
              ]),
            ),
          ),
          if (records.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: EmptyView(
                  title: '조건에 맞는 길드원이 없어요',
                  message: '검색어와 입력 상태 필터를 확인해 주세요.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final record = records[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: _SiegeMemberCard(
                      record: record,
                      rank: overview.records.indexOf(record) + 1,
                      isMe: record.userId == currentUserId,
                      canEdit: canManage,
                      editing: _editingIds.contains(record.userId),
                      onEdit: () => _editMember(record),
                    ),
                  );
                }, childCount: records.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.space8)),
        ],
      ),
    );
  }

  List<SiegeRecord> _filteredRecords(List<SiegeRecord> records) {
    final query = _searchController.text.trim().toLowerCase();
    return records.where((record) {
      final matchesQuery =
          query.isEmpty ||
          record.nickname.toLowerCase().contains(query) ||
          record.mainClass.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _SiegeEntryFilter.all => true,
        _SiegeEntryFilter.entered => record.hasEntry,
        _SiegeEntryFilter.missing => !record.hasEntry,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _editMember(SiegeRecord record) async {
    final input = await showModalBottomSheet<SiegeInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SiegeEditSheet(record: record),
    );
    if (input == null || !mounted) return;
    setState(() => _editingIds.add(record.userId));
    try {
      await ref
          .read(siegeOverviewProvider.notifier)
          .saveMember(record.userId, input);
      if (mounted) _showMessage('${record.nickname}님의 기록을 수정했습니다.');
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _editingIds.remove(record.userId));
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '공성전 데이터를 전체 초기화할까요?',
      message: '모든 길드원의 시작 전·종료 후 다이아와 수정 시각이 삭제됩니다.',
      confirmLabel: '전체 초기화',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isResetting = true);
    try {
      await ref.read(siegeOverviewProvider.notifier).resetAll();
      if (mounted) _showMessage('공성전 데이터를 전체 초기화했습니다.');
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.appPalette.danger : null,
      ),
    );
  }

  static String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is SiegeValidationException) return error.message;
    return '요청을 처리하지 못했습니다.';
  }
}

class _SiegeSummaryCard extends StatelessWidget {
  const _SiegeSummaryCard({required this.overview});

  final SiegeOverview overview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.appPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  child: Icon(
                    Icons.diamond_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('길드 다이아 요약', style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '${overview.enteredCount}/${overview.records.length}명 입력 완료',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: <Widget>[
              _DiamondSummaryValue(label: '시작 전', value: overview.totalStart),
              _DiamondSummaryValue(
                label: '종료 후',
                value: overview.totalRemaining,
                color: context.appPalette.accent,
              ),
              _DiamondSummaryValue(
                label: '사용',
                value: overview.totalUsed,
                color: context.appPalette.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiamondSummaryValue extends StatelessWidget {
  const _DiamondSummaryValue({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.space1),
          Text(
            _formatNumber(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MySiegeInputCard extends StatefulWidget {
  const _MySiegeInputCard({required this.record, required this.onSave});

  final SiegeRecord record;
  final Future<void> Function(SiegeInput input) onSave;

  @override
  State<_MySiegeInputCard> createState() => _MySiegeInputCardState();
}

class _MySiegeInputCardState extends State<_MySiegeInputCard> {
  late final TextEditingController _startController;
  late final TextEditingController _remainingController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _remainingController = TextEditingController();
    _syncRecord();
  }

  @override
  void didUpdateWidget(covariant _MySiegeInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.startDiamonds != widget.record.startDiamonds ||
        oldWidget.record.remainingDiamonds != widget.record.remainingDiamonds ||
        oldWidget.record.updatedAt != widget.record.updatedAt) {
      _syncRecord();
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _remainingController.dispose();
    super.dispose();
  }

  void _syncRecord() {
    _startController.text = widget.record.hasEntry
        ? '${widget.record.startDiamonds}'
        : '';
    _remainingController.text = widget.record.hasEntry
        ? '${widget.record.remainingDiamonds}'
        : '';
  }

  SiegeInput get _input => SiegeInput(
    startDiamonds: int.tryParse(_startController.text) ?? 0,
    remainingDiamonds: int.tryParse(_remainingController.text) ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final validation = _error ?? input.validationMessage;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('내 공성전 기록', style: AppTextStyles.cardTitle),
              ),
              StatusTag(
                label: widget.record.hasEntry ? '입력 완료' : '미입력',
                foregroundColor: widget.record.hasEntry
                    ? context.appPalette.success
                    : context.appPalette.warning,
                backgroundColor: widget.record.hasEntry
                    ? context.appPalette.successSoft
                    : context.appPalette.warningSoft,
                icon: widget.record.hasEntry
                    ? Icons.check_rounded
                    : Icons.edit_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          const Text(
            '공성 시작 전과 종료 후 잔여 다이아를 입력해 주세요.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.space4),
          _DiamondInputField(
            controller: _startController,
            label: '공성 시작 전 다이아',
            icon: Icons.shield_outlined,
            onChanged: _onChanged,
          ),
          const SizedBox(height: AppSpacing.space3),
          _DiamondInputField(
            controller: _remainingController,
            label: '공성 종료 후 다이아',
            icon: Icons.flag_outlined,
            onChanged: _onChanged,
          ),
          const SizedBox(height: AppSpacing.space3),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appPalette.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('사용 다이아', style: AppTextStyles.label),
                  ),
                  Text(
                    _formatNumber(input.usedDiamonds),
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: input.usedDiamonds < 0
                          ? context.appPalette.danger
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (validation != null) ...<Widget>[
            const SizedBox(height: AppSpacing.space2),
            Text(
              validation,
              style: AppTextStyles.caption.copyWith(
                color: context.appPalette.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving || input.validationMessage != null
                  ? null
                  : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '저장 중' : '내 기록 저장'),
            ),
          ),
        ],
      ),
    );
  }

  void _onChanged(String _) => setState(() => _error = null);

  Future<void> _save() async {
    final input = _input;
    final validation = input.validationMessage;
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(input);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('내 공성전 기록을 저장했습니다.')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _SiegeScreenState._messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DiamondInputField extends StatelessWidget {
  const _DiamondInputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: '다이아',
      ),
      onChanged: onChanged,
    );
  }
}

class _SiegeMemberCard extends StatelessWidget {
  const _SiegeMemberCard({
    required this.record,
    required this.rank,
    required this.isMe,
    required this.canEdit,
    required this.editing,
    required this.onEdit,
  });

  final SiegeRecord record;
  final int rank;
  final bool isMe;
  final bool canEdit;
  final bool editing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: isMe ? Theme.of(context).colorScheme.primary : null,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 19,
                backgroundColor: context.appPalette.primarySoft,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '$rank',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
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
                        Flexible(
                          child: Text(
                            record.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong,
                          ),
                        ),
                        if (isMe) ...<Widget>[
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            '나',
                            style: AppTextStyles.caption.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${record.mainClass.isEmpty ? '클래스 미입력' : record.mainClass} · '
                      '전투력 ${_formatNumber(record.combatPower)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (canEdit)
                editing
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onEdit,
                        tooltip: '${record.nickname} 기록 수정',
                        icon: const Icon(Icons.edit_outlined),
                      )
              else
                StatusTag(
                  label: record.hasEntry ? '입력' : '미입력',
                  foregroundColor: record.hasEntry
                      ? context.appPalette.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  backgroundColor: record.hasEntry
                      ? context.appPalette.successSoft
                      : context.appPalette.surfaceSubtle,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              _RecordValue(label: '시작 전', value: record.startDiamonds),
              _RecordValue(label: '종료 후', value: record.remainingDiamonds),
              _RecordValue(
                label: '사용',
                value: record.usedDiamonds,
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              record.updatedAt == null
                  ? '아직 입력하지 않았습니다.'
                  : '마지막 수정 ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(record.updatedAt!)}',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.space1),
          Text(
            _formatNumber(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
              color: emphasized ? context.appPalette.danger : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SiegeEditSheet extends StatefulWidget {
  const _SiegeEditSheet({required this.record});

  final SiegeRecord record;

  @override
  State<_SiegeEditSheet> createState() => _SiegeEditSheetState();
}

class _SiegeEditSheetState extends State<_SiegeEditSheet> {
  late final TextEditingController _startController;
  late final TextEditingController _remainingController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: '${widget.record.startDiamonds}',
    );
    _remainingController = TextEditingController(
      text: '${widget.record.remainingDiamonds}',
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _remainingController.dispose();
    super.dispose();
  }

  SiegeInput get _input => SiegeInput(
    startDiamonds: int.tryParse(_startController.text) ?? 0,
    remainingDiamonds: int.tryParse(_remainingController.text) ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final input = _input;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${widget.record.nickname} 기록 수정',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '${widget.record.mainClass} · 전투력 ${_formatNumber(widget.record.combatPower)}',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.space4),
            _DiamondInputField(
              controller: _startController,
              label: '공성 시작 전 다이아',
              icon: Icons.shield_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.space3),
            _DiamondInputField(
              controller: _remainingController,
              label: '공성 종료 후 다이아',
              icon: Icons.flag_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('사용 다이아', style: AppTextStyles.label),
                ),
                Text(
                  _formatNumber(input.usedDiamonds),
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: context.appPalette.danger,
                  ),
                ),
              ],
            ),
            if (input.validationMessage case final message?) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Text(
                message,
                style: AppTextStyles.caption.copyWith(
                  color: context.appPalette.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: input.isValid
                    ? () => Navigator.of(context).pop(input)
                    : null,
                child: const Text('변경 내용 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final negative = value < 0;
  final chars = value.abs().toString().split('').reversed.toList();
  final grouped = <String>[];
  for (var index = 0; index < chars.length; index++) {
    if (index > 0 && index % 3 == 0) grouped.add(',');
    grouped.add(chars[index]);
  }
  return '${negative ? '-' : ''}${grouped.reversed.join()}';
}
