import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../application/support_controller.dart';
import '../domain/support_request.dart';

enum _SupportFilter { active, mine, closed }

enum _ManageAction { done, canceled, reopen, delete }

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  _SupportFilter _filter = _SupportFilter.active;
  final Set<String> _busyActions = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportOverviewProvider);
    final session = ref.watch(authControllerProvider).value;
    final currentUserId = session?.effectiveUserId ?? session?.userId ?? 0;
    final canManageAll = RoleGuard.canManageSupport(
      session?.role ?? UserRole.unknown,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('손지원'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                ref.read(supportOverviewProvider.notifier).refreshOverview(),
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('요청 등록'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: isDeputyFeatureForbidden(error) ? '권한 안내' : '문제가 발생했어요',
          message: deputyPermissionMessage(error),
          onRetry: isDeputyCharacterRequired(error)
              ? () => context.go('/deputy/characters')
              : isDeputyFeatureForbidden(error)
              ? null
              : () => ref.invalidate(supportOverviewProvider),
          actionLabel: isDeputyCharacterRequired(error) ? '캐릭터 선택' : null,
          onAction: isDeputyCharacterRequired(error)
              ? () => context.go('/deputy/characters')
              : null,
        ),
        data: (overview) => _buildBody(
          overview,
          currentUserId: currentUserId,
          canManageAll: canManageAll,
        ),
      ),
    );
  }

  Widget _buildBody(
    SupportOverview overview, {
    required int currentUserId,
    required bool canManageAll,
  }) {
    final requests = _filteredRequests(overview, currentUserId);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(supportOverviewProvider.notifier).refreshOverview(),
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
                _SupportSummaryCard(
                  overview: overview,
                  currentUserId: currentUserId,
                ),
                const SizedBox(height: AppSpacing.space4),
                _PrivacyNotice(),
                const SizedBox(height: AppSpacing.space6),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('요청 목록', style: AppTextStyles.sectionTitle),
                    ),
                    Text('${requests.length}건', style: AppTextStyles.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_SupportFilter>(
                    segments: <ButtonSegment<_SupportFilter>>[
                      ButtonSegment<_SupportFilter>(
                        value: _SupportFilter.active,
                        label: Text(
                          '진행중 ${overview.countFor(SupportRequestStatus.open) + overview.countFor(SupportRequestStatus.matched)}',
                        ),
                      ),
                      ButtonSegment<_SupportFilter>(
                        value: _SupportFilter.mine,
                        label: Text(
                          '내 활동 ${overview.relatedCount(currentUserId)}',
                        ),
                      ),
                      ButtonSegment<_SupportFilter>(
                        value: _SupportFilter.closed,
                        label: Text(
                          '종료 ${overview.countFor(SupportRequestStatus.done) + overview.countFor(SupportRequestStatus.canceled)}',
                        ),
                      ),
                    ],
                    selected: <_SupportFilter>{_filter},
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
          if (requests.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: EmptyView(
                  title: _filter == _SupportFilter.active
                      ? '진행 중인 손지원이 없어요'
                      : '조건에 맞는 요청이 없어요',
                  message: _filter == _SupportFilter.active
                      ? '도움이 필요하면 요청을 등록해 주세요.'
                      : '다른 상태 필터를 확인해 주세요.',
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
                  final request = requests[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                    child: _SupportRequestCard(
                      request: request,
                      currentUserId: currentUserId,
                      canManage:
                          canManageAll || request.isRequester(currentUserId),
                      busy: _busyActions.any(
                        (key) => key.startsWith('${request.id}:'),
                      ),
                      onApply: () => _apply(request),
                      onCancelApplication: (application) =>
                          _cancelApplication(request, application),
                      onSelectApplication: (application) =>
                          _selectApplication(request, application),
                      onManage: (action) => _manage(request, action),
                    ),
                  );
                }, childCount: requests.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 104)),
        ],
      ),
    );
  }

  List<SupportRequest> _filteredRequests(
    SupportOverview overview,
    int currentUserId,
  ) {
    return overview.requests.where((request) {
      return switch (_filter) {
        _SupportFilter.active =>
          request.status == SupportRequestStatus.open ||
              request.status == SupportRequestStatus.matched,
        _SupportFilter.mine => request.isRelatedTo(currentUserId),
        _SupportFilter.closed =>
          request.status == SupportRequestStatus.done ||
              request.status == SupportRequestStatus.canceled,
      };
    }).toList();
  }

  Future<void> _openCreateSheet() async {
    final input = await showModalBottomSheet<SupportRequestInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _SupportRequestSheet(),
    );
    if (input == null || !mounted) return;
    await _run('create', () async {
      await ref.read(supportOverviewProvider.notifier).createRequest(input);
      _showMessage('손지원 요청을 등록했습니다.');
    });
  }

  Future<void> _apply(SupportRequest request) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${request.nickname}님을 지원할까요?',
      message: '${_formatRequestedTime(request.requestedTime)} 손지원에 신청합니다.',
      confirmLabel: '지원 신청',
    );
    if (!confirmed || !mounted) return;
    await _run('${request.id}:apply', () async {
      await ref.read(supportOverviewProvider.notifier).apply(request.id);
      _showMessage('손지원을 신청했습니다.');
    });
  }

  Future<void> _cancelApplication(
    SupportRequest request,
    SupportApplication application,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '손지원 신청을 취소할까요?',
      message: application.isSelected
          ? '선택된 신청을 취소하면 요청이 다시 모집중으로 변경됩니다.'
          : '${request.nickname}님에게 보낸 신청을 취소합니다.',
      confirmLabel: '신청 취소',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run('${request.id}:cancel:${application.id}', () async {
      await ref
          .read(supportOverviewProvider.notifier)
          .cancelApplication(request.id, application.id);
      _showMessage('손지원 신청을 취소했습니다.');
    });
  }

  Future<void> _selectApplication(
    SupportRequest request,
    SupportApplication application,
  ) async {
    if (application.isSelected) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${application.nickname}님을 선택할까요?',
      message:
          '주클래스 ${_mainClass(application.mainClass)} · 전투력 ${_number(application.combatPower)}\n선택하면 요청 상태가 매칭완료로 변경됩니다.',
      confirmLabel: '담당자로 선택',
    );
    if (!confirmed || !mounted) return;
    await _run('${request.id}:select:${application.id}', () async {
      await ref
          .read(supportOverviewProvider.notifier)
          .selectApplication(request.id, application.id);
      _showMessage('${application.nickname}님과 매칭했습니다.');
    });
  }

  Future<void> _manage(SupportRequest request, _ManageAction action) async {
    if (action == _ManageAction.delete) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '손지원 요청을 삭제할까요?',
        message: '요청과 모든 신청 내역이 함께 삭제되며 되돌릴 수 없습니다.',
        confirmLabel: '삭제',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      await _run('${request.id}:delete', () async {
        await ref
            .read(supportOverviewProvider.notifier)
            .deleteRequest(request.id);
        _showMessage('손지원 요청을 삭제했습니다.');
      });
      return;
    }

    final status = switch (action) {
      _ManageAction.done => SupportRequestStatus.done,
      _ManageAction.canceled => SupportRequestStatus.canceled,
      _ManageAction.reopen => SupportRequestStatus.open,
      _ManageAction.delete => throw StateError('unreachable'),
    };
    final confirmed = await showAppConfirmDialog(
      context,
      title: "요청을 '${status.label}' 상태로 변경할까요?",
      message: status == SupportRequestStatus.open
          ? '기존 신청 내역을 유지한 채 다시 지원자를 모집합니다.'
          : '요청 목록의 상태가 즉시 변경됩니다.',
      confirmLabel: status.label,
      destructive: status == SupportRequestStatus.canceled,
    );
    if (!confirmed || !mounted) return;
    await _run('${request.id}:status', () async {
      await ref
          .read(supportOverviewProvider.notifier)
          .updateStatus(request.id, status);
      _showMessage("요청을 '${status.label}' 상태로 변경했습니다.");
    });
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busyActions.add(key));
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      if (isDeputyCharacterRequired(error)) {
        context.go('/deputy/characters');
        return;
      }
      _showMessage(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.appPalette.danger : null,
      ),
    );
  }

  static String _messageFor(Object error) {
    if (error is ApiException) return deputyPermissionMessage(error);
    if (error is SupportValidationException) return error.message;
    return '손지원 요청을 처리하지 못했습니다.';
  }
}

class _SupportSummaryCard extends StatelessWidget {
  const _SupportSummaryCard({
    required this.overview,
    required this.currentUserId,
  });

  final SupportOverview overview;
  final int currentUserId;

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
                    Icons.volunteer_activism_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('길드 손지원 현황', style: AppTextStyles.cardTitle),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      '도움이 필요한 시간과 지원자를 빠르게 연결해요.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: <Widget>[
              _SummaryValue(
                label: '모집중',
                value: overview.countFor(SupportRequestStatus.open),
                color: context.appPalette.success,
              ),
              _SummaryValue(
                label: '매칭완료',
                value: overview.countFor(SupportRequestStatus.matched),
                color: Theme.of(context).colorScheme.primary,
              ),
              _SummaryValue(
                label: '내 활동',
                value: overview.relatedCount(currentUserId),
                color: context.appPalette.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.space1),
          Text(
            '$value건',
            style: AppTextStyles.sectionTitle.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, size: 18),
            SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Text(
                '접속 정보는 개인 연락으로 전달하고, 앱에는 요청 시간과 매칭 정보만 남겨 주세요.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportRequestCard extends StatelessWidget {
  const _SupportRequestCard({
    required this.request,
    required this.currentUserId,
    required this.canManage,
    required this.busy,
    required this.onApply,
    required this.onCancelApplication,
    required this.onSelectApplication,
    required this.onManage,
  });

  final SupportRequest request;
  final int currentUserId;
  final bool canManage;
  final bool busy;
  final VoidCallback onApply;
  final ValueChanged<SupportApplication> onCancelApplication;
  final ValueChanged<SupportApplication> onSelectApplication;
  final ValueChanged<_ManageAction> onManage;

  @override
  Widget build(BuildContext context) {
    final isMine = request.isRequester(currentUserId);
    final myApplication = request.applicationFor(currentUserId);
    final statusColors = _statusColors(context, request.status);
    return AppCard(
      borderColor: isMine ? Theme.of(context).colorScheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: context.appPalette.primarySoft,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  request.nickname.isEmpty
                      ? '?'
                      : request.nickname.characters.first,
                  style: AppTextStyles.bodyStrong,
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
                            request.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                        if (isMine) ...<Widget>[
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            '내 요청',
                            style: AppTextStyles.caption.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              StatusTag(
                label: request.status.label,
                foregroundColor: statusColors.$1,
                backgroundColor: statusColors.$2,
                icon: _statusIcon(request.status),
              ),
              if (canManage) ...<Widget>[
                const SizedBox(width: 2),
                PopupMenuButton<_ManageAction>(
                  enabled: !busy,
                  tooltip: '${request.nickname} 요청 관리',
                  onSelected: onManage,
                  itemBuilder: (context) => <PopupMenuEntry<_ManageAction>>[
                    if (request.status != SupportRequestStatus.done)
                      const PopupMenuItem(
                        value: _ManageAction.done,
                        child: Text('완료 처리'),
                      ),
                    if (request.status != SupportRequestStatus.canceled)
                      const PopupMenuItem(
                        value: _ManageAction.canceled,
                        child: Text('요청 취소'),
                      ),
                    if (request.status != SupportRequestStatus.open)
                      const PopupMenuItem(
                        value: _ManageAction.reopen,
                        child: Text('다시 모집'),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _ManageAction.delete,
                      child: Text('요청 삭제'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: _RequestMetricTile(
                  icon: Icons.shield_outlined,
                  label: '주클래스',
                  value: _mainClass(request.mainClass),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: _RequestMetricTile(
                  icon: Icons.bolt_rounded,
                  label: '전투력',
                  value: _number(request.combatPower),
                  emphasized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appPalette.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space3,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: context.appPalette.success,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      _formatRequestedTime(request.requestedTime),
                      style: AppTextStyles.bodyStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (request.memo.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.space3),
            Text(request.memo.trim(), style: AppTextStyles.label),
          ],
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              Icon(
                Icons.group_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  '지원자 ${request.applications.length}명',
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              if (myApplication != null)
                Text(
                  myApplication.isSelected ? '내가 선택됨' : '신청 완료',
                  style: AppTextStyles.caption.copyWith(
                    color: myApplication.isSelected
                        ? context.appPalette.success
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          _ApplicantPreview(
            request: request,
            currentUserId: currentUserId,
            canManage: canManage,
            busy: busy,
            onCancel: onCancelApplication,
            onSelect: onSelectApplication,
          ),
          if (request.canApply(currentUserId)) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onApply,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('손지원 신청'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicantPreview extends StatelessWidget {
  const _ApplicantPreview({
    required this.request,
    required this.currentUserId,
    required this.canManage,
    required this.busy,
    required this.onCancel,
    required this.onSelect,
  });

  final SupportRequest request;
  final int currentUserId;
  final bool canManage;
  final bool busy;
  final ValueChanged<SupportApplication> onCancel;
  final ValueChanged<SupportApplication> onSelect;

  @override
  Widget build(BuildContext context) {
    if (request.applications.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.appPalette.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.space3),
          child: Center(
            child: Text('아직 신청한 길드원이 없어요.', style: AppTextStyles.caption),
          ),
        ),
      );
    }
    final sorted = List<SupportApplication>.of(request.applications)
      ..sort((a, b) {
        if (a.isSelected != b.isSelected) return a.isSelected ? -1 : 1;
        return b.combatPower.compareTo(a.combatPower);
      });
    final visible = sorted.take(3).toList();
    return Column(
      children: <Widget>[
        for (final application in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: _ApplicantRow(
              application: application,
              isMine: application.applicantId == currentUserId,
              canManage: canManage,
              busy: busy,
              onCancel: () => onCancel(application),
              onSelect: () => onSelect(application),
            ),
          ),
        if (sorted.length > visible.length)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _showAll(context, sorted),
              child: Text('지원자 전체 보기 (${sorted.length}명)'),
            ),
          ),
      ],
    );
  }

  Future<void> _showAll(
    BuildContext context,
    List<SupportApplication> applications,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.space3,
              ),
              child: Text(
                '지원자 ${applications.length}명',
                style: AppTextStyles.sectionTitle,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  0,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space6,
                ),
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  final application = applications[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                    child: _ApplicantRow(
                      application: application,
                      isMine: application.applicantId == currentUserId,
                      canManage: canManage,
                      busy: busy,
                      onCancel: () {
                        Navigator.of(context).pop();
                        onCancel(application);
                      },
                      onSelect: () {
                        Navigator.of(context).pop();
                        onSelect(application);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  const _ApplicantRow({
    required this.application,
    required this.isMine,
    required this.canManage,
    required this.busy,
    required this.onCancel,
    required this.onSelect,
  });

  final SupportApplication application;
  final bool isMine;
  final bool canManage;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: application.isSelected
            ? context.appPalette.successSoft
            : context.appPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: application.isSelected
            ? Border.all(
                color: context.appPalette.success.withValues(alpha: 0.4),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          application.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong,
                        ),
                      ),
                      if (isMine) ...<Widget>[
                        const SizedBox(width: AppSpacing.space1),
                        Text(
                          '나',
                          style: AppTextStyles.caption.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      if (application.isSelected) ...<Widget>[
                        const SizedBox(width: AppSpacing.space2),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: context.appPalette.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '선택',
                          style: AppTextStyles.caption.copyWith(
                            color: context.appPalette.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Wrap(
                    spacing: AppSpacing.space3,
                    runSpacing: 2,
                    children: <Widget>[
                      _CompactMetric(
                        label: '주클래스',
                        value: _mainClass(application.mainClass),
                      ),
                      _CompactMetric(
                        label: '전투력',
                        value: _number(application.combatPower),
                        valueColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canManage && !application.isSelected)
              TextButton(
                onPressed: busy ? null : onSelect,
                child: const Text('선택'),
              ),
            if (isMine)
              IconButton(
                onPressed: busy ? null : onCancel,
                tooltip: '${application.nickname} 신청 취소',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestMetricTile extends StatelessWidget {
  const _RequestMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? context.appPalette.primarySoft
            : context.appPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: AppTextStyles.caption),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(color: foreground),
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

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label ', style: AppTextStyles.caption),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SupportRequestSheet extends StatefulWidget {
  const _SupportRequestSheet();

  @override
  State<_SupportRequestSheet> createState() => _SupportRequestSheetState();
}

class _SupportRequestSheetState extends State<_SupportRequestSheet> {
  late DateTime _date;
  late TimeOfDay _start;
  TimeOfDay? _end;
  bool _allDay = false;
  final _memoController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    final roundedMinute = ((now.minute + 4) ~/ 5) * 5;
    _start = TimeOfDay(
      hour: (now.hour + (roundedMinute ~/ 60)) % 24,
      minute: roundedMinute % 60,
    );
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('손지원 요청 등록', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space2),
            const Text(
              '길드원이 확인할 수 있는 요청 시간과 필요한 작업만 적어 주세요.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.space5),
            _PickerTile(
              icon: Icons.calendar_today_outlined,
              label: '요청 날짜',
              value: DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.space3),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('종일'),
              subtitle: const Text('시간을 정하지 않고 날짜만 표시합니다.'),
              value: _allDay,
              onChanged: (value) => setState(() => _allDay = value),
            ),
            if (!_allDay) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule_rounded,
                      label: '시작',
                      value: _formatTime(_start),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.timelapse_rounded,
                      label: '종료',
                      value: _end == null ? '선택 안함' : _formatTime(_end!),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            TextField(
              controller: _memoController,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '메모',
                alignLabelWithHint: true,
                hintText: '필요한 작업, 주의사항, 가능한 연락 시간',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error case final error?) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Text(
                error,
                style: AppTextStyles.caption.copyWith(
                  color: context.appPalette.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('요청 등록'),
              ),
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
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _start : (_end ?? _start);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final normalized = TimeOfDay(
      hour: picked.hour,
      minute: ((picked.minute / 5).round() * 5).clamp(0, 55),
    );
    setState(() {
      _error = null;
      if (isStart) {
        _start = normalized;
      } else {
        _end = normalized;
      }
    });
  }

  void _submit() {
    if (!_allDay && _end != null && _minutes(_end!) <= _minutes(_start)) {
      setState(() => _error = '종료 시간은 시작 시간보다 늦게 선택해 주세요.');
      return;
    }
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final requestedTime = _allDay
        ? '$date 종일'
        : '$date ${_formatTime(_start)}${_end == null ? '' : '~${_formatTime(_end!)}'}';
    final input = SupportRequestInput(
      requestedTime: requestedTime,
      memo: _memoController.text,
    );
    final validation = input.validationMessage;
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    Navigator.of(context).pop(input);
  }

  static int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: context.appPalette.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: AppTextStyles.caption),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong,
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

(Color, Color) _statusColors(
  BuildContext context,
  SupportRequestStatus status,
) {
  final palette = context.appPalette;
  return switch (status) {
    SupportRequestStatus.open => (palette.success, palette.successSoft),
    SupportRequestStatus.matched => (
      Theme.of(context).colorScheme.primary,
      palette.primarySoft,
    ),
    SupportRequestStatus.done => (
      Theme.of(context).colorScheme.onSurfaceVariant,
      palette.surfaceSubtle,
    ),
    SupportRequestStatus.canceled => (palette.danger, palette.dangerSoft),
  };
}

IconData _statusIcon(SupportRequestStatus status) => switch (status) {
  SupportRequestStatus.open => Icons.wifi_tethering_rounded,
  SupportRequestStatus.matched => Icons.handshake_outlined,
  SupportRequestStatus.done => Icons.check_rounded,
  SupportRequestStatus.canceled => Icons.close_rounded,
};

String _formatRequestedTime(String value) {
  final normalized = value.trim().replaceAll('T', ' ');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return normalized.isEmpty ? '-' : normalized;
  return DateFormat('yyyy.MM.dd (E) HH:mm', 'ko_KR').format(parsed.toLocal());
}

String _number(int value) => NumberFormat.decimalPattern('ko_KR').format(value);

String _mainClass(String value) => value.trim().isEmpty ? '미입력' : value.trim();
