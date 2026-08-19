import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../members/application/members_controller.dart';
import '../../members/domain/guild_member.dart';
import '../application/notice_controller.dart';
import '../domain/boss_control_chapter.dart';
import '../domain/notice_article.dart';
import '../domain/notice_overview.dart';
import 'notice_editor_sheet.dart';

enum _NoticeTab { rules, prices, controls }

enum _ArticleAction { moveUp, moveDown, edit, delete }

class NoticeScreen extends ConsumerStatefulWidget {
  const NoticeScreen({super.key});

  @override
  ConsumerState<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends ConsumerState<NoticeScreen> {
  _NoticeTab _selectedTab = _NoticeTab.rules;
  final Set<int> _expandedRuleIds = <int>{};
  final Set<String> _changingBosses = <String>{};
  bool _isMutating = false;

  bool get _canManage {
    final role =
        ref.read(authControllerProvider).value?.role ?? UserRole.unknown;
    return RoleGuard.canManageNotices(role);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(noticeOverviewProvider);
    final session = ref.watch(authControllerProvider).value;
    final canManage = RoleGuard.canManageNotices(
      session?.role ?? UserRole.unknown,
    );
    final members = ref.watch(membersControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지'),
        actions: <Widget>[
          if (canManage && _selectedTab != _NoticeTab.controls)
            IconButton(
              onPressed: _isMutating ? null : _createArticle,
              tooltip: _selectedTab == _NoticeTab.rules ? '길드룰 등록' : '가격표 등록',
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error is ApiException ? error.message : '공지를 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(noticeOverviewProvider),
        ),
        data: (data) =>
            _buildBody(data, members: members, canManage: canManage),
      ),
    );
  }

  Widget _buildBody(
    NoticeOverview overview, {
    required AsyncValue<List<GuildMember>> members,
    required bool canManage,
  }) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space8,
        ),
        children: <Widget>[
          _buildOverviewCard(members, canManage),
          const SizedBox(height: AppSpacing.space5),
          SegmentedButton<_NoticeTab>(
            segments: const <ButtonSegment<_NoticeTab>>[
              ButtonSegment<_NoticeTab>(
                value: _NoticeTab.rules,
                icon: Icon(Icons.rule_rounded),
                label: Text('길드룰'),
              ),
              ButtonSegment<_NoticeTab>(
                value: _NoticeTab.prices,
                icon: Icon(Icons.diamond_outlined),
                label: Text('가격표'),
              ),
              ButtonSegment<_NoticeTab>(
                value: _NoticeTab.controls,
                icon: Icon(Icons.shield_outlined),
                label: Text('보스 통제'),
              ),
            ],
            selected: <_NoticeTab>{_selectedTab},
            onSelectionChanged: (selection) {
              setState(() => _selectedTab = selection.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.space6),
          ...switch (_selectedTab) {
            _NoticeTab.rules => _ruleWidgets(overview.rules, canManage),
            _NoticeTab.prices => _priceWidgets(overview.priceGuides, canManage),
            _NoticeTab.controls => _controlWidgets(
              overview.bossControls,
              canManage,
            ),
          },
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    AsyncValue<List<GuildMember>> members,
    bool canManage,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return AppCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  child: Icon(Icons.campaign_rounded, color: scheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('길드 운영 안내', style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '내규와 거래 기준, 보스 통제 상태를 한곳에서 확인하세요.',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
              StatusTag(
                label: canManage ? '관리 가능' : '읽기 전용',
                foregroundColor: canManage ? palette.success : scheme.primary,
                backgroundColor: canManage
                    ? palette.successSoft
                    : palette.primarySoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('현재 운영진', style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.space2),
          members.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) =>
                Text('운영진 정보를 불러오지 못했습니다.', style: AppTextStyles.caption),
            data: (items) {
              final staff = items
                  .where((member) => RoleGuard.isStaff(member.role))
                  .toList();
              if (staff.isEmpty) {
                return Text('등록된 운영진이 없습니다.', style: AppTextStyles.label);
              }
              return Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: staff.map((member) {
                  final isMaster = member.role == UserRole.master;
                  return StatusTag(
                    label: '${member.nickname} · ${member.role.label}',
                    foregroundColor: isMaster
                        ? palette.warning
                        : scheme.primary,
                    backgroundColor: isMaster
                        ? palette.warningSoft
                        : palette.primarySoft,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _ruleWidgets(List<NoticeArticle> articles, bool canManage) {
    if (articles.isEmpty) {
      return const <Widget>[
        EmptyView(title: '등록된 길드룰이 없어요', message: '운영진이 새 내규를 등록하면 여기에 표시됩니다.'),
      ];
    }
    return List<Widget>.generate(articles.length, (index) {
      final article = articles[index];
      final expanded = _expandedRuleIds.contains(article.id);
      final accent = _articleColor(article.color);
      final preview = _articlePreview(article);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: AppCard(
          borderColor: accent.withValues(alpha: .34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(article.title, style: AppTextStyles.cardTitle),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          '수정 ${_formatUpdatedAt(article.updatedAt)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    _articleMenu(
                      type: NoticeArticleType.rule,
                      article: article,
                      index: index,
                      itemCount: articles.length,
                    ),
                ],
              ),
              if (!expanded && preview.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ],
              if (expanded) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                ...article.sections.map(
                  (section) => _buildRuleSection(section, accent),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    if (expanded) {
                      _expandedRuleIds.remove(article.id);
                    } else {
                      _expandedRuleIds.add(article.id);
                    }
                  }),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(expanded ? '접기' : '전체 보기'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRuleSection(NoticeSection section, Color accent) {
    final isPlain = section.title == '상단 안내' || section.title == '마무리';
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isPlain && section.title != '길드 내규') ...<Widget>[
            Text(section.title, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.space2),
          ],
          ...List<Widget>.generate(section.rows.length, (index) {
            final row = section.rows[index];
            final hasLabel = row.label.isNotEmpty;
            final isLast = index == section.rows.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (hasLabel)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${index + 1}.',
                            style: AppTextStyles.label.copyWith(color: accent),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.label,
                            style: AppTextStyles.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: hasLabel ? 28 : 0,
                      top: hasLabel ? AppSpacing.space1 : 0,
                    ),
                    child: Text(row.value, style: AppTextStyles.body),
                  ),
                  if (!isLast) ...<Widget>[
                    const SizedBox(height: AppSpacing.space3),
                    Padding(
                      padding: EdgeInsets.only(left: hasLabel ? 28 : 0),
                      child: Divider(height: 1, color: palette.cardBorder),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _priceWidgets(List<NoticeArticle> articles, bool canManage) {
    if (articles.isEmpty) {
      return const <Widget>[
        EmptyView(title: '등록된 가격표가 없어요', message: '아이템 거래 기준이 등록되면 여기에 표시됩니다.'),
      ];
    }
    return articles.map((article) {
      final accent = _articleColor(article.color);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
        child: AppCard(
          borderColor: accent.withValues(alpha: .34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.diamond_outlined, color: accent),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(article.title, style: AppTextStyles.cardTitle),
                        Text(
                          '수정 ${_formatUpdatedAt(article.updatedAt)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    _articleMenu(
                      type: NoticeArticleType.priceGuide,
                      article: article,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              ...article.sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(section.title, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.space2),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.appPalette.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space3,
                            vertical: AppSpacing.space2,
                          ),
                          child: Column(
                            children: section.rows.map((row) {
                              final isFree =
                                  row.value.contains('무상') ||
                                  row.value.contains('지원');
                              final valueColor = isFree
                                  ? context.appPalette.success
                                  : accent;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.space2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        row.label,
                                        style: AppTextStyles.label,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.space3),
                                    Text(
                                      _formatPrice(row.value),
                                      style: AppTextStyles.bodyStrong.copyWith(
                                        color: valueColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.space1),
                                    Icon(
                                      Icons.diamond_outlined,
                                      size: 15,
                                      color: valueColor,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _controlWidgets(
    List<BossControlChapter> chapters,
    bool canManage,
  ) {
    if (chapters.isEmpty) {
      return const <Widget>[
        EmptyView(title: '보스 통제 정보가 없어요', message: '서버의 보스 통제 설정을 확인해 주세요.'),
      ];
    }
    final palette = context.appPalette;
    return <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('상태 안내', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: <Widget>[
                StatusTag(
                  label: '통제',
                  foregroundColor: palette.danger,
                  backgroundColor: palette.dangerSoft,
                ),
                StatusTag(
                  label: '동맹 한정',
                  foregroundColor: palette.warning,
                  backgroundColor: palette.warningSoft,
                ),
                StatusTag(
                  label: '통제 없음',
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: palette.primarySoft,
                ),
              ],
            ),
            if (canManage) ...<Widget>[
              const SizedBox(height: AppSpacing.space3),
              Text(
                '보스를 누르면 통제 없음 → 동맹 한정 → 통제 순서로 변경됩니다.',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.space3),
      ...chapters.map((chapter) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space3),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: chapter == chapters.first,
              title: Text(chapter.chapter, style: AppTextStyles.cardTitle),
              subtitle: Text(
                '${chapter.bosses.length}개 보스',
                style: AppTextStyles.caption,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                0,
                AppSpacing.space4,
                AppSpacing.space4,
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpacing.space2,
                    runSpacing: AppSpacing.space2,
                    children: chapter.bosses.map((boss) {
                      final colors = _controlColors(boss.status);
                      final key = '${chapter.chapter}::${boss.name}';
                      final changing = _changingBosses.contains(key);
                      return ActionChip(
                        onPressed: canManage && !changing
                            ? () => _cycleBoss(chapter, boss)
                            : null,
                        avatar: changing
                            ? SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.$1,
                                ),
                              )
                            : Icon(
                                _controlIcon(boss.status),
                                size: 15,
                                color: colors.$1,
                              ),
                        label: Text('${boss.name} · ${boss.statusLabel}'),
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: colors.$1,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: colors.$2,
                        disabledColor: colors.$2,
                        side: BorderSide(
                          color: colors.$1.withValues(alpha: .32),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Widget _articleMenu({
    required NoticeArticleType type,
    required NoticeArticle article,
    int? index,
    int? itemCount,
  }) {
    return PopupMenuButton<_ArticleAction>(
      enabled: !_isMutating,
      tooltip: '관리 메뉴',
      onSelected: (action) => _handleArticleAction(
        action,
        type: type,
        article: article,
        index: index,
      ),
      itemBuilder: (context) => <PopupMenuEntry<_ArticleAction>>[
        if (type == NoticeArticleType.rule) ...<PopupMenuEntry<_ArticleAction>>[
          PopupMenuItem<_ArticleAction>(
            value: _ArticleAction.moveUp,
            enabled: index != null && index > 0,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.arrow_upward_rounded),
              title: Text('위로 이동'),
            ),
          ),
          PopupMenuItem<_ArticleAction>(
            value: _ArticleAction.moveDown,
            enabled: index != null && index < (itemCount ?? 0) - 1,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.arrow_downward_rounded),
              title: Text('아래로 이동'),
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem<_ArticleAction>(
          value: _ArticleAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('수정'),
          ),
        ),
        PopupMenuItem<_ArticleAction>(
          value: _ArticleAction.delete,
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

  Future<void> _createArticle() async {
    if (!_canManage) return;
    final type = _selectedTab == _NoticeTab.rules
        ? NoticeArticleType.rule
        : NoticeArticleType.priceGuide;
    final input = await showNoticeEditorSheet(context, type: type);
    if (input == null || !mounted) return;
    await _runMutation(
      () => ref
          .read(noticeOverviewProvider.notifier)
          .saveArticle(type: type, input: input),
      type == NoticeArticleType.rule ? '길드룰을 등록했습니다.' : '가격표를 등록했습니다.',
    );
  }

  Future<void> _handleArticleAction(
    _ArticleAction action, {
    required NoticeArticleType type,
    required NoticeArticle article,
    int? index,
  }) async {
    if (!_canManage) return;
    switch (action) {
      case _ArticleAction.moveUp:
      case _ArticleAction.moveDown:
        if (index == null) return;
        await _runMutation(
          () => ref
              .read(noticeOverviewProvider.notifier)
              .moveRule(index, action == _ArticleAction.moveUp ? -1 : 1),
          '길드룰 순서를 변경했습니다.',
        );
      case _ArticleAction.edit:
        final input = await showNoticeEditorSheet(
          context,
          type: type,
          article: article,
        );
        if (input == null || !mounted) return;
        await _runMutation(
          () => ref
              .read(noticeOverviewProvider.notifier)
              .saveArticle(type: type, articleId: article.id, input: input),
          '변경사항을 저장했습니다.',
        );
      case _ArticleAction.delete:
        final confirmed = await showAppConfirmDialog(
          context,
          title: '${article.title}을 삭제할까요?',
          message: '삭제한 공지는 복구할 수 없습니다.',
          confirmLabel: '삭제',
          destructive: true,
        );
        if (!confirmed || !mounted) return;
        await _runMutation(
          () => ref
              .read(noticeOverviewProvider.notifier)
              .deleteArticle(type, article.id),
          '공지를 삭제했습니다.',
        );
    }
  }

  Future<void> _cycleBoss(BossControlChapter chapter, BossControl boss) async {
    final key = '${chapter.chapter}::${boss.name}';
    setState(() => _changingBosses.add(key));
    try {
      await ref
          .read(noticeOverviewProvider.notifier)
          .cycleBossControl(
            chapter: chapter.chapter,
            boss: boss.name,
            currentStatus: boss.status,
          );
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _changingBosses.remove(key));
    }
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
      if (mounted) _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(noticeOverviewProvider.notifier).refreshOverview(),
      ref.read(membersControllerProvider.notifier).refreshMembers(),
    ]);
  }

  void _showMessage(String message, {bool isError = false}) {
    final palette = context.appPalette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? palette.danger : null,
      ),
    );
  }

  String _errorMessage(Object error) {
    return error is ApiException ? error.message : '요청을 처리하지 못했습니다.';
  }

  Color _articleColor(String rawColor) {
    final palette = context.appPalette;
    final normalized = rawColor.toLowerCase();
    const colors = <String, Color>{
      '#94a3b8': Color(0xFF94A3B8),
      '#f2b705': Color(0xFFF2B705),
      '#fbbf24': Color(0xFFFBBF24),
      '#c9542b': Color(0xFFC9542B),
      '#ef4444': Color(0xFFEF4444),
      '#f43f5e': Color(0xFFF43F5E),
      '#d946ef': Color(0xFFD946EF),
      '#a78bfa': Color(0xFFD946EF),
      '#8b5cf6': Color(0xFF8B5CF6),
      '#6366f1': Color(0xFF6366F1),
      '#3b82f6': Color(0xFF3B82F6),
      '#38bdf8': Color(0xFF38BDF8),
      '#22d3ee': Color(0xFF22D3EE),
      '#14b8a6': Color(0xFF14B8A6),
      '#22c55e': Color(0xFF22C55E),
      '#84cc16': Color(0xFF84CC16),
      '#a3e635': Color(0xFFA3E635),
    };
    if (normalized == '#f8fafc' || normalized == '#d1d5db') {
      return palette.isDark
          ? const Color(0xFFF8FAFC)
          : Theme.of(context).colorScheme.primary;
    }
    return colors[normalized] ?? Theme.of(context).colorScheme.primary;
  }

  (Color, Color) _controlColors(String status) {
    final palette = context.appPalette;
    return switch (status) {
      'CONTROL' => (palette.danger, palette.dangerSoft),
      'ALLY_ONLY' => (palette.warning, palette.warningSoft),
      _ => (Theme.of(context).colorScheme.primary, palette.primarySoft),
    };
  }

  IconData _controlIcon(String status) {
    return switch (status) {
      'CONTROL' => Icons.block_rounded,
      'ALLY_ONLY' => Icons.handshake_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
  }

  static String _articlePreview(NoticeArticle article) {
    for (final section in article.sections) {
      for (final row in section.rows) {
        if (row.value.trim().isNotEmpty) return row.value.trim();
      }
    }
    return '';
  }

  static String _formatUpdatedAt(DateTime? value) {
    if (value == null) return '-';
    final seoul = value.toUtc().add(const Duration(hours: 9));
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${seoul.year}-${twoDigits(seoul.month)}-${twoDigits(seoul.day)} '
        '${twoDigits(seoul.hour)}:${twoDigits(seoul.minute)}';
  }

  static String _formatPrice(String value) {
    final raw = value.trim();
    final digits = raw.replaceAll(',', '');
    final number = int.tryParse(digits);
    if (number == null) return raw;
    final chars = number.toString().split('').reversed.toList();
    final grouped = <String>[];
    for (var index = 0; index < chars.length; index++) {
      if (index > 0 && index % 3 == 0) grouped.add(',');
      grouped.add(chars[index]);
    }
    return grouped.reversed.join();
  }
}
