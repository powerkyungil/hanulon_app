import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radii.dart';
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
import '../application/collection_controller.dart';
import '../domain/collection_overview.dart';
import '../domain/item_collection.dart';
import 'collection_editor_sheet.dart';

enum _CollectionView { personal, guild }

enum _GuildCompareView { members, items }

enum _ItemMemberFilter { all, missing, completed }

enum _CollectionAction { edit, delete }

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final _searchController = TextEditingController();
  _CollectionView _selectedView = _CollectionView.personal;
  _GuildCompareView _guildCompareView = _GuildCompareView.items;
  int? _selectedMemberId;
  int? _selectedCollectionId;
  final Set<String> _changingKeys = <String>{};
  bool _isMutating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionOverviewProvider);
    final session = ref.watch(authControllerProvider).value;
    final role = session?.role ?? UserRole.unknown;
    final canManage = RoleGuard.canManageCollections(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('아이템 현황'),
        actions: <Widget>[
          if (canManage) ...<Widget>[
            IconButton(
              onPressed: _isMutating ? null : _showExclusions,
              tooltip: '우선순위 제외 관리',
              icon: const Icon(Icons.person_off_outlined),
            ),
            IconButton(
              onPressed: _isMutating ? null : () => _editCollection(),
              tooltip: '컬렉션 추가',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error is ApiException
              ? error.message
              : '아이템 현황을 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(collectionOverviewProvider),
        ),
        data: (overview) => _buildBody(
          overview,
          currentUserId: session?.userId ?? 0,
          role: role,
        ),
      ),
    );
  }

  Widget _buildBody(
    CollectionOverview overview, {
    required int currentUserId,
    required UserRole role,
  }) {
    final selectedMemberId = _resolvedMemberId(overview, currentUserId);
    final collections = _filteredCollections(overview.collections);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(collectionOverviewProvider.notifier).refreshOverview(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space8,
        ),
        children: <Widget>[
          _buildSummary(overview, currentUserId),
          const SizedBox(height: AppSpacing.space5),
          SegmentedButton<_CollectionView>(
            segments: const <ButtonSegment<_CollectionView>>[
              ButtonSegment<_CollectionView>(
                value: _CollectionView.personal,
                icon: Icon(Icons.person_outline_rounded),
                label: Text('개인 현황'),
              ),
              ButtonSegment<_CollectionView>(
                value: _CollectionView.guild,
                icon: Icon(Icons.groups_outlined),
                label: Text('길드 비교'),
              ),
            ],
            selected: <_CollectionView>{_selectedView},
            onSelectionChanged: (selection) {
              setState(() => _selectedView = selection.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.space5),
          if (_selectedView == _CollectionView.personal)
            _buildMemberSelector(overview, selectedMemberId),
          if (_selectedView == _CollectionView.personal)
            const SizedBox(height: AppSpacing.space3),
          if (_selectedView == _CollectionView.guild) ...<Widget>[
            _buildGuildCompareSelector(),
            const SizedBox(height: AppSpacing.space3),
          ],
          _buildFilters(overview.collections),
          const SizedBox(height: AppSpacing.space5),
          if (collections.isEmpty)
            const EmptyView(
              title: '조건에 맞는 아이템이 없어요',
              message: '검색어와 컬렉션 필터를 확인해 주세요.',
            )
          else if (_selectedView == _CollectionView.personal)
            ..._buildPersonalCollections(
              overview,
              collections,
              selectedMemberId: selectedMemberId,
              currentUserId: currentUserId,
              role: role,
            )
          else if (_guildCompareView == _GuildCompareView.members)
            ..._buildMemberComparison(overview, collections)
          else
            ..._buildGuildCollections(
              overview,
              collections,
              currentUserId: currentUserId,
              role: role,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(CollectionOverview overview, int currentUserId) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  child: Icon(Icons.inventory_2_rounded, color: scheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('컬렉션 달성 현황', style: AppTextStyles.cardTitle),
                    SizedBox(height: AppSpacing.space1),
                    Text(
                      '고정 아이템 ID로 체크 기록을 안전하게 관리합니다.',
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
              _SummaryValue(label: '길드원', value: '${overview.members.length}명'),
              _SummaryValue(label: '아이템', value: '${overview.itemCount}개'),
              _SummaryValue(
                label: '내 달성률',
                value: '${overview.completionPercent(currentUserId)}%',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('다른 길드원의 최신 변경은 새로고침할 때 반영됩니다.', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildMemberSelector(
    CollectionOverview overview,
    int selectedMemberId,
  ) {
    final member = overview.members
        .where((item) => item.id == selectedMemberId)
        .firstOrNull;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<int>(
            initialValue: selectedMemberId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '확인할 길드원',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
            items: overview.members
                .map(
                  (member) => DropdownMenuItem<int>(
                    value: member.id,
                    child: Text(
                      '${member.nickname} · ${_formatNumber(member.combatPower)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedMemberId = value),
          ),
          if (member != null) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: <Widget>[
                Expanded(
                  child: LinearProgressIndicator(
                    value: overview.itemCount == 0
                        ? 0
                        : overview.completedCount(member.id) /
                              overview.itemCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Text(
                  '${overview.completedCount(member.id)}/${overview.itemCount} · '
                  '${overview.completionPercent(member.id)}%',
                  style: AppTextStyles.bodyStrong,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(List<ItemCollection> collections) {
    return Column(
      children: <Widget>[
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '컬렉션, 부위 또는 강화 검색',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space3),
        DropdownButtonFormField<int?>(
          initialValue: _selectedCollectionId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '컬렉션 필터',
            prefixIcon: Icon(Icons.filter_list_rounded),
          ),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(value: null, child: Text('모든 컬렉션')),
            ...collections.map(
              (collection) => DropdownMenuItem<int?>(
                value: collection.id,
                child: Text(collection.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _selectedCollectionId = value),
        ),
      ],
    );
  }

  Widget _buildGuildCompareSelector() {
    return SegmentedButton<_GuildCompareView>(
      segments: const <ButtonSegment<_GuildCompareView>>[
        ButtonSegment<_GuildCompareView>(
          value: _GuildCompareView.members,
          icon: Icon(Icons.badge_outlined),
          label: Text('길드원 기준'),
        ),
        ButtonSegment<_GuildCompareView>(
          value: _GuildCompareView.items,
          icon: Icon(Icons.inventory_2_outlined),
          label: Text('아이템 기준'),
        ),
      ],
      selected: <_GuildCompareView>{_guildCompareView},
      onSelectionChanged: (selection) {
        setState(() => _guildCompareView = selection.first);
      },
      showSelectedIcon: false,
    );
  }

  List<Widget> _buildMemberComparison(
    CollectionOverview overview,
    List<ItemCollection> collections,
  ) {
    return List<Widget>.generate(overview.members.length, (index) {
      final member = overview.members[index];
      final visibleItemCount = collections.fold<int>(
        0,
        (total, collection) => total + collection.items.length,
      );
      final completedCount = collections.fold<int>(
        0,
        (total, collection) =>
            total +
            collection.items
                .where((item) => overview.isCompleted(member.id, item.id))
                .length,
      );
      final percent = visibleItemCount == 0
          ? 0
          : (completedCount / visibleItemCount * 100).round();
      final isExcluded = overview.excludedMemberIds.contains(member.id);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: context.appPalette.primarySoft,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Row(
              children: <Widget>[
                Expanded(
                  child: Text(member.nickname, style: AppTextStyles.cardTitle),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.appPalette.primarySoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space3,
                      vertical: AppSpacing.space1,
                    ),
                    child: Text(
                      '전투력 ${_formatNumber(member.combatPower)}',
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space1),
              child: Row(
                children: <Widget>[
                  Text(member.role.label, style: AppTextStyles.caption),
                  if (isExcluded) ...<Widget>[
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '분배 후순위',
                      style: AppTextStyles.caption.copyWith(
                        color: context.appPalette.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '$completedCount/$visibleItemCount · $percent%',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              0,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            children: <Widget>[
              LinearProgressIndicator(
                value: visibleItemCount == 0
                    ? 0
                    : completedCount / visibleItemCount,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: AppSpacing.space4),
              ...collections.map((collection) {
                final collectionCompleted = collection.items
                    .where((item) => overview.isCompleted(member.id, item.id))
                    .length;
                final collectionPercent = collection.items.isEmpty
                    ? 0
                    : (collectionCompleted / collection.items.length * 100)
                          .round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(collection.name, style: AppTextStyles.label),
                            const SizedBox(height: AppSpacing.space1),
                            LinearProgressIndicator(
                              value: collection.items.isEmpty
                                  ? 0
                                  : collectionCompleted /
                                        collection.items.length,
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space4),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '$collectionCompleted/${collection.items.length} · '
                          '$collectionPercent%',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _buildPersonalCollections(
    CollectionOverview overview,
    List<ItemCollection> collections, {
    required int selectedMemberId,
    required int currentUserId,
    required UserRole role,
  }) {
    final canEdit = RoleGuard.canEditCollectionStatus(
      role: role,
      currentUserId: currentUserId,
      targetUserId: selectedMemberId,
    );
    return collections.map((collection) {
      final completed = collection.items
          .where((item) => overview.isCompleted(selectedMemberId, item.id))
          .length;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: collection == collections.first,
            title: Text(collection.name, style: AppTextStyles.cardTitle),
            subtitle: Text(
              '$completed/${collection.items.length} 달성',
              style: AppTextStyles.caption,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (RoleGuard.canManageCollections(role))
                  _collectionMenu(collection),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              0,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            children: collection.items.map((item) {
              final isCompleted = overview.isCompleted(
                selectedMemberId,
                item.id,
              );
              final priority = overview.priorityFor(item.id);
              final key = CollectionOverview.statusKey(
                selectedMemberId,
                item.id,
              );
              return _ItemStatusRow(
                item: item,
                completed: isCompleted,
                priority: priority,
                canEdit: canEdit,
                changing: _changingKeys.contains(key),
                onChanged: canEdit
                    ? () => _toggleStatus(selectedMemberId, item.id)
                    : null,
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGuildCollections(
    CollectionOverview overview,
    List<ItemCollection> collections, {
    required int currentUserId,
    required UserRole role,
  }) {
    return collections.map((collection) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: collection == collections.first,
            title: Text(collection.name, style: AppTextStyles.cardTitle),
            subtitle: Text(
              '${collection.items.length}개 아이템',
              style: AppTextStyles.caption,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (RoleGuard.canManageCollections(role))
                  _collectionMenu(collection),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              0,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            children: collection.items.map((item) {
              final priority = overview.priorityFor(item.id);
              final completedCount = overview.members
                  .where((member) => overview.isCompleted(member.id, item.id))
                  .length;
              final memberCount = overview.members.length;
              final missingCount = memberCount - completedCount;
              final completionRate = memberCount == 0
                  ? 0.0
                  : completedCount / memberCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.appPalette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.part,
                                    style: AppTextStyles.bodyStrong,
                                  ),
                                  Text(
                                    item.enchantment,
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(completionRate * 100).round()}%',
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        LinearProgressIndicator(
                          value: completionRate,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        Text(
                          '보유 $completedCount명 · 미보유 $missingCount명',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        _PriorityLabel(
                          priority: priority,
                          showCombatPower: true,
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showItemMembers(
                              item: item,
                              currentUserId: currentUserId,
                              role: role,
                            ),
                            icon: const Icon(Icons.groups_outlined),
                            label: Text('길드원 현황 $memberCount명'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }

  Widget _collectionMenu(ItemCollection collection) {
    return PopupMenuButton<_CollectionAction>(
      enabled: !_isMutating,
      tooltip: '컬렉션 관리',
      onSelected: (action) {
        switch (action) {
          case _CollectionAction.edit:
            _editCollection(collection);
          case _CollectionAction.delete:
            _deleteCollection(collection);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_CollectionAction>>[
        const PopupMenuItem<_CollectionAction>(
          value: _CollectionAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('수정'),
          ),
        ),
        PopupMenuItem<_CollectionAction>(
          value: _CollectionAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: context.appPalette.danger,
            ),
            title: Text(
              '삭제',
              style: TextStyle(color: context.appPalette.danger),
            ),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }

  Future<void> _showItemMembers({
    required CollectionItem item,
    required int currentUserId,
    required UserRole role,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ItemMembersSheet(
        item: item,
        currentUserId: currentUserId,
        role: role,
      ),
    );
  }

  Future<void> _toggleStatus(int userId, int itemId) async {
    final key = CollectionOverview.statusKey(userId, itemId);
    if (_changingKeys.contains(key)) return;
    setState(() => _changingKeys.add(key));
    try {
      await ref
          .read(collectionOverviewProvider.notifier)
          .toggleCompleted(userId: userId, itemId: itemId);
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _changingKeys.remove(key));
    }
  }

  Future<void> _editCollection([ItemCollection? collection]) async {
    final input = await showCollectionEditorSheet(
      context,
      collection: collection,
    );
    if (input == null || !mounted) return;
    await _runMutation(
      () => ref
          .read(collectionOverviewProvider.notifier)
          .saveCollection(input, collectionId: collection?.id),
      collection == null ? '컬렉션을 등록했습니다.' : '컬렉션을 수정했습니다.',
    );
  }

  Future<void> _deleteCollection(ItemCollection collection) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${collection.name}을 삭제할까요?',
      message: '포함된 아이템과 모든 길드원의 체크 기록이 함께 삭제됩니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => ref
          .read(collectionOverviewProvider.notifier)
          .deleteCollection(collection.id),
      '컬렉션을 삭제했습니다.',
    );
  }

  Future<void> _showExclusions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _ExclusionSheet(),
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action,
    String message,
  ) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await action();
      if (mounted) _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  List<ItemCollection> _filteredCollections(List<ItemCollection> collections) {
    final query = _searchController.text.trim().toLowerCase();
    return collections
        .where(
          (collection) =>
              _selectedCollectionId == null ||
              collection.id == _selectedCollectionId,
        )
        .map((collection) {
          if (query.isEmpty || collection.name.toLowerCase().contains(query)) {
            return collection;
          }
          final items = collection.items
              .where(
                (item) =>
                    item.part.toLowerCase().contains(query) ||
                    item.enchantment.toLowerCase().contains(query),
              )
              .toList();
          return ItemCollection(
            id: collection.id,
            name: collection.name,
            items: items,
          );
        })
        .where((collection) => collection.items.isNotEmpty)
        .toList();
  }

  int _resolvedMemberId(CollectionOverview overview, int currentUserId) {
    if (overview.members.any((member) => member.id == _selectedMemberId)) {
      return _selectedMemberId!;
    }
    if (overview.members.any((member) => member.id == currentUserId)) {
      return currentUserId;
    }
    return overview.members.firstOrNull?.id ?? 0;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.appPalette.danger : null,
      ),
    );
  }

  String _errorMessage(Object error) {
    return error is ApiException ? error.message : '요청을 처리하지 못했습니다.';
  }

  static String _formatNumber(int value) {
    final chars = value.toString().split('').reversed.toList();
    final grouped = <String>[];
    for (var index = 0; index < chars.length; index++) {
      if (index > 0 && index % 3 == 0) grouped.add(',');
      grouped.add(chars[index]);
    }
    return grouped.reversed.join();
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

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
          Text(value, style: AppTextStyles.sectionTitle),
        ],
      ),
    );
  }
}

class _ItemStatusRow extends StatelessWidget {
  const _ItemStatusRow({
    required this.item,
    required this.completed,
    required this.priority,
    required this.canEdit,
    required this.changing,
    required this.onChanged,
  });

  final CollectionItem item;
  final bool completed;
  final CollectionPriority? priority;
  final bool canEdit;
  final bool changing;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    final isInteractive = canEdit && !changing;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Semantics(
        button: isInteractive,
        checked: completed,
        enabled: isInteractive,
        label: '${item.part} ${completed ? '달성' : '미달성'}',
        hint: isInteractive ? '두 번 탭하여 상태 변경' : '읽기 전용',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: completed ? palette.primarySoft : palette.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: completed
                  ? scheme.primary.withValues(alpha: 0.38)
                  : palette.cardBorder.withValues(alpha: 0.72),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isInteractive ? onChanged : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space4,
                  AppSpacing.space3,
                  AppSpacing.space2,
                  AppSpacing.space3,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.part, style: AppTextStyles.bodyStrong),
                          const SizedBox(height: AppSpacing.space1),
                          Text(item.enchantment, style: AppTextStyles.caption),
                          const SizedBox(height: AppSpacing.space2),
                          _PriorityLabel(priority: priority),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    if (changing)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    else
                      _LargeCompletionCheckbox(
                        completed: completed,
                        enabled: canEdit,
                        onChanged: onChanged,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeCompletionCheckbox extends StatelessWidget {
  const _LargeCompletionCheckbox({
    required this.completed,
    required this.enabled,
    required this.onChanged,
  });

  final bool completed;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: 48,
            child: Center(
              child: ExcludeSemantics(
                child: Transform.scale(
                  scale: 1.35,
                  child: Checkbox(
                    value: completed,
                    onChanged: enabled ? (_) => onChanged?.call() : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: enabled
                          ? scheme.primary.withValues(alpha: 0.72)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.48),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            completed ? '달성' : '미달성',
            style: AppTextStyles.caption.copyWith(
              color: completed ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityLabel extends StatelessWidget {
  const _PriorityLabel({required this.priority, this.showCombatPower = false});

  final CollectionPriority? priority;
  final bool showCombatPower;

  @override
  Widget build(BuildContext context) {
    if (priority == null) {
      return StatusTag(
        label: '전원 달성',
        foregroundColor: context.appPalette.success,
        backgroundColor: context.appPalette.successSoft,
        icon: Icons.check_rounded,
      );
    }
    final palette = context.appPalette;
    final combatPowerLabel = showCombatPower
        ? ' · ${_CollectionsScreenState._formatNumber(priority!.member.combatPower)}'
        : '';
    return StatusTag(
      label:
          '1순위 ${priority!.member.nickname}'
          '$combatPowerLabel'
          '${priority!.isExcluded ? ' · 후순위' : ''}',
      foregroundColor: priority!.isExcluded
          ? palette.warning
          : Theme.of(context).colorScheme.primary,
      backgroundColor: priority!.isExcluded
          ? palette.warningSoft
          : palette.primarySoft,
      icon: showCombatPower ? null : Icons.flag_outlined,
    );
  }
}

class _ItemMembersSheet extends ConsumerStatefulWidget {
  const _ItemMembersSheet({
    required this.item,
    required this.currentUserId,
    required this.role,
  });

  final CollectionItem item;
  final int currentUserId;
  final UserRole role;

  @override
  ConsumerState<_ItemMembersSheet> createState() => _ItemMembersSheetState();
}

class _ItemMembersSheetState extends ConsumerState<_ItemMembersSheet> {
  final _searchController = TextEditingController();
  final Set<int> _changingMemberIds = <int>{};
  _ItemMemberFilter _filter = _ItemMemberFilter.missing;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewState = ref.watch(collectionOverviewProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: overviewState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error is ApiException
              ? error.message
              : '길드원 현황을 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(collectionOverviewProvider),
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(CollectionOverview overview) {
    final completedCount = overview.members
        .where((member) => overview.isCompleted(member.id, widget.item.id))
        .length;
    final missingCount = overview.members.length - completedCount;
    final priority = overview.priorityFor(widget.item.id);
    final query = _searchController.text.trim().toLowerCase();
    final members = overview.members.where((member) {
      final completed = overview.isCompleted(member.id, widget.item.id);
      final matchesFilter = switch (_filter) {
        _ItemMemberFilter.all => true,
        _ItemMemberFilter.missing => !completed,
        _ItemMemberFilter.completed => completed,
      };
      return matchesFilter && member.nickname.toLowerCase().contains(query);
    }).toList();

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
          Text(widget.item.part, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.space1),
          Text(
            '${widget.item.enchantment} · 전투력 높은 순',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              _SheetSummaryValue(
                label: '전체',
                value: '${overview.members.length}명',
              ),
              _SheetSummaryValue(label: '미보유', value: '$missingCount명'),
              _SheetSummaryValue(label: '보유', value: '$completedCount명'),
            ],
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
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_ItemMemberFilter>(
              segments: <ButtonSegment<_ItemMemberFilter>>[
                ButtonSegment<_ItemMemberFilter>(
                  value: _ItemMemberFilter.all,
                  label: Text('전체 ${overview.members.length}'),
                ),
                ButtonSegment<_ItemMemberFilter>(
                  value: _ItemMemberFilter.missing,
                  label: Text('미보유 $missingCount'),
                ),
                ButtonSegment<_ItemMemberFilter>(
                  value: _ItemMemberFilter.completed,
                  label: Text('보유 $completedCount'),
                ),
              ],
              selected: <_ItemMemberFilter>{_filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text('조건에 맞는 길드원이 없어요.', style: AppTextStyles.label),
                  )
                : ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final completed = overview.isCompleted(
                        member.id,
                        widget.item.id,
                      );
                      final canEdit = RoleGuard.canEditCollectionStatus(
                        role: widget.role,
                        currentUserId: widget.currentUserId,
                        targetUserId: member.id,
                      );
                      final isChanging = _changingMemberIds.contains(member.id);
                      final isExcluded = overview.excludedMemberIds.contains(
                        member.id,
                      );
                      final guildRank =
                          overview.members.indexWhere(
                            (value) => value.id == member.id,
                          ) +
                          1;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: canEdit && !isChanging
                            ? () => _toggle(member.id)
                            : null,
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundColor: context.appPalette.primarySoft,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            '$guildRank',
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                member.nickname,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong,
                              ),
                            ),
                            if (priority?.member.id == member.id) ...<Widget>[
                              const SizedBox(width: AppSpacing.space2),
                              Text(
                                '1순위',
                                style: AppTextStyles.caption.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '전투력 ${_CollectionsScreenState._formatNumber(member.combatPower)}'
                          ' · ${member.role.label}'
                          '${isExcluded ? ' · 분배 후순위' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: isExcluded
                                ? context.appPalette.warning
                                : null,
                          ),
                        ),
                        trailing: isChanging
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : SizedBox(
                                width: 48,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      completed
                                          ? Icons.check_circle_rounded
                                          : Icons.remove_circle_outline_rounded,
                                      size: 20,
                                      color: completed
                                          ? context.appPalette.success
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                    Text(
                                      completed ? '보유' : '미보유',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(int memberId) async {
    setState(() => _changingMemberIds.add(memberId));
    try {
      await ref
          .read(collectionOverviewProvider.notifier)
          .toggleCompleted(userId: memberId, itemId: widget.item.id);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : '아이템 상태를 변경하지 못했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.appPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changingMemberIds.remove(memberId));
    }
  }
}

class _SheetSummaryValue extends StatelessWidget {
  const _SheetSummaryValue({required this.label, required this.value});

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

class _ExclusionSheet extends ConsumerStatefulWidget {
  const _ExclusionSheet();

  @override
  ConsumerState<_ExclusionSheet> createState() => _ExclusionSheetState();
}

class _ExclusionSheetState extends ConsumerState<_ExclusionSheet> {
  final Set<int> _changingIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(collectionOverviewProvider).value;
    return FractionallySizedBox(
      heightFactor: .78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space2,
              AppSpacing.screenHorizontal,
              AppSpacing.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('우선순위 제외 길드원', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '선택한 길드원은 미보유자 1순위 계산에서 후순위로 표시됩니다.',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: overview == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.space3,
                    ),
                    itemCount: overview.members.length,
                    itemBuilder: (context, index) {
                      final member = overview.members[index];
                      final excluded = overview.excludedMemberIds.contains(
                        member.id,
                      );
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: excluded,
                        onChanged: _changingIds.contains(member.id)
                            ? null
                            : (_) => _toggle(member.id),
                        title: Text(member.nickname),
                        subtitle: Text(
                          '${member.role.label} · 전투력 '
                          '${_CollectionsScreenState._formatNumber(member.combatPower)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(int userId) async {
    setState(() => _changingIds.add(userId));
    try {
      await ref
          .read(collectionOverviewProvider.notifier)
          .toggleExcluded(userId);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : '우선순위 설정을 변경하지 못했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.appPalette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changingIds.remove(userId));
    }
  }
}
