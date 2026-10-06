import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../members/domain/guild_member.dart';
import '../application/content_group_controller.dart';
import '../domain/content_group.dart';

enum _ContentGroupTab { groups, unassigned }

class ContentGroupsScreen extends ConsumerStatefulWidget {
  const ContentGroupsScreen({super.key});

  @override
  ConsumerState<ContentGroupsScreen> createState() =>
      _ContentGroupsScreenState();
}

class _ContentGroupsScreenState extends ConsumerState<ContentGroupsScreen> {
  final _searchController = TextEditingController();
  _ContentGroupTab _tab = _ContentGroupTab.groups;
  bool _isMutating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewState = ref.watch(contentGroupOverviewProvider);
    final session = ref.watch(authControllerProvider).value;
    final role = session?.role ?? UserRole.unknown;
    final canManage = RoleGuard.canManageContentGroups(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('콘텐츠 참여'),
        actions: <Widget>[
          IconButton(
            onPressed: _isMutating
                ? null
                : () => ref
                      .read(contentGroupOverviewProvider.notifier)
                      .refreshOverview(),
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canManage)
            IconButton(
              onPressed: _isMutating ? null : _createGroup,
              tooltip: '새 그룹 생성',
              icon: const Icon(Icons.add_rounded),
            ),
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
              : () => ref.invalidate(contentGroupOverviewProvider),
          actionLabel: isDeputyCharacterRequired(error) ? '캐릭터 선택' : null,
          onAction: isDeputyCharacterRequired(error)
              ? () => context.go('/deputy/characters')
              : null,
        ),
        data: (overview) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return _buildWide(overview, canManage: canManage);
            }
            return _buildMobile(overview, canManage: canManage);
          },
        ),
      ),
    );
  }

  Widget _buildMobile(
    ContentGroupOverview overview, {
    required bool canManage,
  }) {
    final groups = _filteredGroups(overview);
    final unassigned = _filteredUnassigned(overview);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(contentGroupOverviewProvider.notifier).refreshOverview(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space8,
        ),
        children: <Widget>[
          _OverviewCard(overview: overview),
          if (!canManage) ...<Widget>[
            const SizedBox(height: AppSpacing.space3),
            _ReadOnlyNotice(),
          ],
          const SizedBox(height: AppSpacing.space5),
          SegmentedButton<_ContentGroupTab>(
            segments: <ButtonSegment<_ContentGroupTab>>[
              ButtonSegment<_ContentGroupTab>(
                value: _ContentGroupTab.groups,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text('그룹 ${overview.groups.length}'),
              ),
              ButtonSegment<_ContentGroupTab>(
                value: _ContentGroupTab.unassigned,
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text('미편성 ${overview.unassignedMembers.length}'),
              ),
            ],
            selected: <_ContentGroupTab>{_tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _tab = selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _SearchField(controller: _searchController, onChanged: _onSearch),
          const SizedBox(height: AppSpacing.space5),
          if (_tab == _ContentGroupTab.groups)
            if (groups.isEmpty)
              EmptyView(
                title: overview.groups.isEmpty ? '생성된 그룹이 없어요' : '검색 결과가 없어요',
                message: canManage && overview.groups.isEmpty
                    ? '오른쪽 위 + 버튼으로 첫 그룹을 만들어 주세요.'
                    : '그룹명이나 길드원 닉네임을 다시 확인해 주세요.',
              )
            else
              ...groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: _buildGroupCard(overview, group, canManage: canManage),
                ),
              )
          else
            _buildUnassignedPanel(
              overview,
              unassigned,
              canManage: canManage,
              embedded: true,
            ),
        ],
      ),
    );
  }

  Widget _buildWide(ContentGroupOverview overview, {required bool canManage}) {
    final groups = _filteredGroups(overview);
    final unassigned = _filteredUnassigned(overview);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
        AppSpacing.screenHorizontal,
        AppSpacing.space5,
      ),
      child: Column(
        children: <Widget>[
          _OverviewCard(overview: overview),
          const SizedBox(height: AppSpacing.space4),
          _SearchField(controller: _searchController, onChanged: _onSearch),
          const SizedBox(height: AppSpacing.space4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: _buildUnassignedPanel(
                    overview,
                    unassigned,
                    canManage: canManage,
                    embedded: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.space4),
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              '그룹 편성',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ),
                          Text('${groups.length}개', style: AppTextStyles.label),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      if (groups.isEmpty)
                        const EmptyView(
                          title: '표시할 그룹이 없어요',
                          message: '새 그룹을 만들거나 검색어를 확인해 주세요.',
                        )
                      else
                        ...groups.map(
                          (group) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.space3,
                            ),
                            child: _buildGroupCard(
                              overview,
                              group,
                              canManage: canManage,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedPanel(
    ContentGroupOverview overview,
    List<GuildMember> members, {
    required bool canManage,
    required bool embedded,
  }) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => canManage,
      onAcceptWithDetails: (details) => _moveMember(details.data, null),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        final content = Column(
          mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('미편성 길드원', style: AppTextStyles.sectionTitle),
                ),
                Text('${members.length}명', style: AppTextStyles.label),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              canManage
                  ? '길드원을 그룹 카드로 드래그하거나 이동 메뉴를 사용하세요.'
                  : '아직 그룹에 배치되지 않은 길드원입니다.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.space3),
            if (members.isEmpty)
              const EmptyView(
                title: '미편성 길드원이 없어요',
                message: '모든 길드원이 그룹에 배치되어 있습니다.',
              )
            else if (embedded)
              ...members.map(
                (member) => _MemberRow(
                  member: member,
                  canManage: canManage,
                  onMove: () => _showMoveMember(overview, member),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberRow(
                      member: member,
                      canManage: canManage,
                      onMove: () => _showMoveMember(overview, member),
                    );
                  },
                ),
              ),
          ],
        );
        if (embedded) return content;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: highlighted
                ? context.appPalette.primarySoft
                : context.appPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? Theme.of(context).colorScheme.primary
                  : context.appPalette.cardBorder,
            ),
          ),
          child: content,
        );
      },
    );
  }

  Widget _buildGroupCard(
    ContentGroupOverview overview,
    ContentGroup group, {
    required bool canManage,
  }) {
    final members = overview.membersFor(group);
    final preview = members.take(4).toList();
    final totalPower = members.fold<int>(
      0,
      (total, member) => total + member.combatPower,
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          canManage && !group.memberIds.contains(details.data),
      onAcceptWithDetails: (details) => _moveMember(details.data, group.id),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AppCard(
          padding: EdgeInsets.zero,
          borderColor: highlighted
              ? Theme.of(context).colorScheme.primary
              : null,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.appPalette.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          Icons.account_tree_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(group.name, style: AppTextStyles.cardTitle),
                          const SizedBox(height: AppSpacing.space1),
                          Text(
                            '${members.length}명 · 합산 전투력 ${_formatNumber(totalPower)}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (canManage) _groupMenu(group),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.space5),
                  child: Text(
                    canManage
                        ? highlighted
                              ? '여기에 배치합니다.'
                              : '길드원을 이 카드로 드래그해 주세요.'
                        : '배치된 길드원이 없습니다.',
                    style: AppTextStyles.label,
                    textAlign: TextAlign.center,
                  ),
                )
              else ...<Widget>[
                for (final member in preview)
                  _MemberRow(
                    member: member,
                    canManage: canManage,
                    onMove: () => _showMoveMember(overview, member),
                  ),
                if (members.length > preview.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                    child: Text(
                      '외 ${members.length - preview.length}명',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showGroupMembers(group.id, canManage),
                  icon: const Icon(Icons.groups_outlined),
                  label: Text('전체 길드원 보기 ${members.length}명'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _groupMenu(ContentGroup group) {
    return PopupMenuButton<String>(
      enabled: !_isMutating,
      tooltip: '그룹 관리',
      onSelected: (value) {
        if (value == 'rename') {
          _renameGroup(group);
        } else if (value == 'delete') {
          _deleteGroup(group);
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'rename',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('이름 변경'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('그룹 삭제'),
          ),
        ),
      ],
    );
  }

  List<ContentGroup> _filteredGroups(ContentGroupOverview overview) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return overview.groups;
    return overview.groups.where((group) {
      if (group.name.toLowerCase().contains(query)) return true;
      return overview
          .membersFor(group)
          .any((member) => member.nickname.toLowerCase().contains(query));
    }).toList();
  }

  List<GuildMember> _filteredUnassigned(ContentGroupOverview overview) {
    final query = _searchController.text.trim().toLowerCase();
    return overview.unassignedMembers
        .where(
          (member) =>
              query.isEmpty || member.nickname.toLowerCase().contains(query),
        )
        .toList();
  }

  void _onSearch(String _) => setState(() {});

  Future<void> _createGroup() async {
    final name = await _showGroupNameDialog(title: '새 그룹 생성');
    if (name == null || !mounted) return;
    await _runMutation(
      () => ref.read(contentGroupOverviewProvider.notifier).createGroup(name),
      '그룹을 생성했습니다.',
    );
  }

  Future<void> _renameGroup(ContentGroup group) async {
    final name = await _showGroupNameDialog(
      title: '그룹 이름 변경',
      initialValue: group.name,
    );
    if (name == null || !mounted || name == group.name) return;
    await _runMutation(
      () => ref
          .read(contentGroupOverviewProvider.notifier)
          .renameGroup(group, name),
      '그룹 이름을 변경했습니다.',
    );
  }

  Future<void> _deleteGroup(ContentGroup group) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${group.name}을 삭제할까요?',
      message: '그룹만 삭제되며 배치된 길드원은 미편성 상태로 이동합니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => ref.read(contentGroupOverviewProvider.notifier).deleteGroup(group),
      '그룹을 삭제했습니다.',
    );
  }

  Future<String?> _showGroupNameDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '그룹 이름'),
          onSubmitted: (_) {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.of(context).pop(value);
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showMoveMember(
    ContentGroupOverview overview,
    GuildMember member,
  ) async {
    final destination = await showMemberGroupPicker(
      context,
      overview: overview,
      member: member,
    );
    if (destination == null || !mounted) return;
    await _moveMember(member.id, destination == 0 ? null : destination);
  }

  Future<void> _moveMember(int memberId, int? targetGroupId) async {
    await _runMutation(
      () => ref
          .read(contentGroupOverviewProvider.notifier)
          .moveMember(memberId, targetGroupId: targetGroupId),
      targetGroupId == null ? '미편성으로 이동했습니다.' : '그룹 배치를 변경했습니다.',
    );
  }

  Future<void> _showGroupMembers(int groupId, bool canManage) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _GroupMembersSheet(groupId: groupId, canManage: canManage),
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      if (isDeputyCharacterRequired(error)) {
        context.go('/deputy/characters');
        return;
      }
      _showMessage(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
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
    return deputyPermissionMessage(error);
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final ContentGroupOverview overview;

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
                    Icons.account_tree_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('콘텐츠 그룹 편성', style: AppTextStyles.cardTitle),
                    SizedBox(height: AppSpacing.space1),
                    Text('콘텐츠별 참여 조합을 한눈에 확인합니다.', style: AppTextStyles.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: <Widget>[
              _OverviewValue(label: '그룹', value: '${overview.groups.length}개'),
              _OverviewValue(
                label: '편성',
                value: '${overview.assignedMemberIds.length}명',
              ),
              _OverviewValue(
                label: '미편성',
                value: '${overview.unassignedMembers.length}명',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.space1),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appPalette.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            Icon(Icons.visibility_outlined, size: 20),
            SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Text(
                '길드원은 현재 편성을 조회할 수 있고, 변경은 운영진이 관리합니다.',
                style: AppTextStyles.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: '그룹명 또는 길드원 닉네임 검색',
        prefixIcon: Icon(Icons.search_rounded),
      ),
      onChanged: onChanged,
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.onMove,
  });

  final GuildMember member;
  final bool canManage;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      minTileHeight: 58,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: context.appPalette.primarySoft,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          member.nickname.characters.firstOrNull ?? '?',
          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        member.nickname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyStrong,
      ),
      subtitle: Text(
        '${member.characterSummary} · 전투력 ${_formatNumber(member.combatPower)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption,
      ),
      trailing: canManage
          ? IconButton(
              onPressed: onMove,
              tooltip: '그룹으로 이동',
              icon: const Icon(Icons.swap_horiz_rounded),
            )
          : null,
    );
    if (!canManage) return tile;
    return LongPressDraggable<int>(
      data: member.id,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 260, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _GroupMembersSheet extends ConsumerStatefulWidget {
  const _GroupMembersSheet({required this.groupId, required this.canManage});

  final int groupId;
  final bool canManage;

  @override
  ConsumerState<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends ConsumerState<_GroupMembersSheet> {
  final _searchController = TextEditingController();
  final Set<int> _movingIds = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentGroupOverviewProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: _ContentGroupsScreenState._messageFor(error),
          onRetry: () => ref.invalidate(contentGroupOverviewProvider),
        ),
        data: (overview) {
          final group = overview.groups
              .where((item) => item.id == widget.groupId)
              .firstOrNull;
          if (group == null) {
            return const EmptyView(
              title: '그룹을 찾을 수 없어요',
              message: '목록을 새로고침해 주세요.',
            );
          }
          final query = _searchController.text.trim().toLowerCase();
          final members = overview
              .membersFor(group)
              .where(
                (member) =>
                    query.isEmpty ||
                    member.nickname.toLowerCase().contains(query),
              )
              .toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.space5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(group.name, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '${overview.membersFor(group).length}명 · 전투력 높은 순',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.space4),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '길드원 닉네임 검색',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.space3),
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text('조건에 맞는 길드원이 없어요.'))
                      : ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final moving = _movingIds.contains(member.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 19,
                                backgroundColor: context.appPalette.primarySoft,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                member.nickname,
                                style: AppTextStyles.bodyStrong,
                              ),
                              subtitle: Text(
                                '${member.characterSummary} · 전투력 ${_formatNumber(member.combatPower)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption,
                              ),
                              trailing: moving
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : widget.canManage
                                  ? IconButton(
                                      onPressed: () => _move(overview, member),
                                      tooltip: '그룹으로 이동',
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _move(ContentGroupOverview overview, GuildMember member) async {
    final destination = await showMemberGroupPicker(
      context,
      overview: overview,
      member: member,
    );
    if (destination == null || !mounted) return;
    setState(() => _movingIds.add(member.id));
    try {
      await ref
          .read(contentGroupOverviewProvider.notifier)
          .moveMember(
            member.id,
            targetGroupId: destination == 0 ? null : destination,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ContentGroupsScreenState._messageFor(error)),
            backgroundColor: context.appPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _movingIds.remove(member.id));
    }
  }
}

Future<int?> showMemberGroupPicker(
  BuildContext context, {
  required ContentGroupOverview overview,
  required GuildMember member,
}) {
  final currentGroupId = overview.groupForMember(member.id)?.id;
  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${member.nickname} 이동', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.space2),
          const Text('배치할 그룹을 선택해 주세요.', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.space3),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_outlined),
                  title: const Text('미편성'),
                  selected: currentGroupId == null,
                  trailing: currentGroupId == null
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: currentGroupId == null
                      ? null
                      : () => Navigator.of(context).pop(0),
                ),
                for (final group in overview.groups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text(group.name),
                    subtitle: Text('${group.memberIds.length}명'),
                    selected: currentGroupId == group.id,
                    trailing: currentGroupId == group.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: currentGroupId == group.id
                        ? null
                        : () => Navigator.of(context).pop(group.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatNumber(int value) {
  final chars = value.toString().split('').reversed.toList();
  final grouped = <String>[];
  for (var index = 0; index < chars.length; index++) {
    if (index > 0 && index % 3 == 0) grouped.add(',');
    grouped.add(chars[index]);
  }
  return grouped.reversed.join();
}
