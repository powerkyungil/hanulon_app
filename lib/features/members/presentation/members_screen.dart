import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/character_options.dart';
import '../../auth/domain/user_role.dart';
import '../application/members_controller.dart';
import '../domain/guild_member.dart';
import '../domain/member_list_query.dart';
import '../domain/member_equipment.dart';
import 'widgets/member_management_menu.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  MemberSortField _sortField = MemberSortField.combatPower;
  bool _descending = true;
  MemberViewMode _viewMode = MemberViewMode.character;
  String? _occupation;
  String? _mainClass;
  String _equipmentPart = CharacterOptions.equipmentParts.first;
  String? _equipmentGrade;
  MemberSkillGroup _skillGroup = MemberSkillGroup.active;
  String _skillName = CharacterOptions.skillNames.first;
  MemberSkillState _skillState = MemberSkillState.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('길드원 명단')),
      body: members.when(
        loading: () => const _MembersLoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException
              ? error.message
              : '길드원 정보를 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(membersControllerProvider),
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(List<GuildMember> allMembers) {
    final visibleMembers = MemberListQuery.apply(
      members: allMembers,
      searchText: _searchController.text,
      sortField: _sortField,
      descending: _descending,
      filters: MemberFilters(
        viewMode: _viewMode,
        occupation: _occupation,
        mainClass: _mainClass,
        equipmentPart: _equipmentPart,
        equipmentGrade: _equipmentGrade,
        skillGroup: _skillGroup,
        skillName: _skillName,
        skillState: _skillState,
      ),
    );
    final currentUserId = ref.watch(authControllerProvider).value?.userId;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(membersControllerProvider.notifier).refreshMembers(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.space2,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space4,
                ),
                sliver: SliverList.list(
                  children: <Widget>[
                    _MembersSummary(members: allMembers),
                    const SizedBox(height: AppSpacing.space4),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '닉네임, 직업, 클래스 검색',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<MemberViewMode>(
                        segments: MemberViewMode.values
                            .map(
                              (mode) => ButtonSegment<MemberViewMode>(
                                value: mode,
                                label: Text(mode.label),
                                icon: Icon(_modeIcon(mode), size: 18),
                              ),
                            )
                            .toList(),
                        selected: <MemberViewMode>{_viewMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setState(() => _viewMode = selection.first);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    _buildModeFilters(),
                    const SizedBox(height: AppSpacing.space3),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            visibleMembers.length == allMembers.length
                                ? '총 ${allMembers.length}명'
                                : '${visibleMembers.length}명 표시',
                            style: AppTextStyles.bodyStrong,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showSortSheet,
                          icon: const Icon(Icons.swap_vert_rounded, size: 19),
                          label: Text(
                            '${_sortField.label} ${_descending ? '높은 순' : '낮은 순'}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (visibleMembers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    title: allMembers.isEmpty ? '등록된 길드원이 없어요' : '검색 결과가 없어요',
                    message: allMembers.isEmpty
                        ? '길드원이 가입하면 이곳에서 장비와 스킬을 확인할 수 있어요.'
                        : '다른 닉네임이나 클래스 이름으로 검색해 보세요.',
                    icon: Icons.groups_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.space8,
                  ),
                  sliver: columns == 1
                      ? SliverList.separated(
                          itemCount: visibleMembers.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.space3),
                          itemBuilder: (context, index) => _MemberCard(
                            member: visibleMembers[index],
                            rank: index + 1,
                            isMe: visibleMembers[index].id == currentUserId,
                            viewMode: _viewMode,
                            equipmentPart: _equipmentPart,
                            skillGroup: _skillGroup,
                            skillName: _skillName,
                          ),
                        )
                      : SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppSpacing.space3,
                                crossAxisSpacing: AppSpacing.space3,
                                mainAxisExtent:
                                    _viewMode == MemberViewMode.character
                                    ? 270
                                    : 220,
                              ),
                          itemCount: visibleMembers.length,
                          itemBuilder: (context, index) => _MemberCard(
                            member: visibleMembers[index],
                            rank: index + 1,
                            isMe: visibleMembers[index].id == currentUserId,
                            viewMode: _viewMode,
                            equipmentPart: _equipmentPart,
                            skillGroup: _skillGroup,
                            skillName: _skillName,
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeFilters() {
    final filters = switch (_viewMode) {
      MemberViewMode.character => Row(
        children: <Widget>[
          Expanded(
            child: _FilterDropdown<String>(
              label: '직업',
              value: _occupation ?? 'all',
              items: <String>[
                'all',
                ...CharacterOptions.classesByOccupation.keys,
              ],
              labelOf: (value) => value == 'all' ? '전체 직업' : value,
              onChanged: (value) {
                setState(() {
                  _occupation = value == 'all' ? null : value;
                  _mainClass = null;
                });
              },
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: _FilterDropdown<String>(
              label: '주클래스',
              value: _mainClass ?? 'all',
              items: <String>[
                'all',
                ...(_occupation == null
                    ? CharacterOptions.allMainClasses
                    : CharacterOptions.classesByOccupation[_occupation]!),
              ],
              labelOf: (value) => value == 'all' ? '전체 클래스' : value,
              onChanged: (value) {
                setState(() => _mainClass = value == 'all' ? null : value);
              },
            ),
          ),
        ],
      ),
      MemberViewMode.equipment => Row(
        children: <Widget>[
          Expanded(
            child: _FilterDropdown<String>(
              label: '장비 부위',
              value: _equipmentPart,
              items: CharacterOptions.equipmentParts,
              labelOf: (value) => value,
              onChanged: (value) => setState(() => _equipmentPart = value),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: _FilterDropdown<String>(
              label: '등급',
              value: _equipmentGrade ?? 'all',
              items: const <String>[
                'all',
                'none',
                'hero',
                'legend',
                'mythic',
                'missing',
              ],
              labelOf: (value) => switch (value) {
                'all' => '전체 등급',
                'missing' => '미입력',
                _ => CharacterOptions.equipmentGrades[value] ?? value,
              },
              onChanged: (value) {
                setState(() => _equipmentGrade = value == 'all' ? null : value);
              },
            ),
          ),
        ],
      ),
      MemberViewMode.skill => Column(
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<MemberSkillGroup>(
              segments: MemberSkillGroup.values
                  .map(
                    (group) => ButtonSegment<MemberSkillGroup>(
                      value: group,
                      label: Text(group.label),
                    ),
                  )
                  .toList(),
              selected: <MemberSkillGroup>{_skillGroup},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _skillGroup = selection.first);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: <Widget>[
              Expanded(
                child: _FilterDropdown<String>(
                  label: '스킬',
                  value: _skillName,
                  items: CharacterOptions.skillNames,
                  labelOf: (value) => value,
                  onChanged: (value) => setState(() => _skillName = value),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: _FilterDropdown<MemberSkillState>(
                  label: '습득 상태',
                  value: _skillState,
                  items: MemberSkillState.values,
                  labelOf: (value) => value.label,
                  onChanged: (value) => setState(() => _skillState = value),
                ),
              ),
            ],
          ),
        ],
      ),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          filters,
          if (_viewMode != MemberViewMode.character) ...<Widget>[
            const SizedBox(height: AppSpacing.space3),
            _ComparisonLegend(mode: _viewMode),
          ],
        ],
      ),
    );
  }

  IconData _modeIcon(MemberViewMode mode) {
    return switch (mode) {
      MemberViewMode.character => Icons.person_outline_rounded,
      MemberViewMode.equipment => Icons.shield_outlined,
      MemberViewMode.skill => Icons.auto_awesome_outlined,
    };
  }

  Future<void> _showSortSheet() async {
    var selectedField = _sortField;
    var descending = _descending;
    final result = await showModalBottomSheet<(MemberSortField, bool)>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
                Text('정렬', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.space3),
                for (final field in MemberSortField.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.label),
                    selected: selectedField == field,
                    trailing: selectedField == field
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => setSheetState(() => selectedField = field),
                  ),
                const SizedBox(height: AppSpacing.space2),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment(value: true, label: Text('높은 순')),
                    ButtonSegment(value: false, label: Text('낮은 순')),
                  ],
                  selected: <bool>{descending},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setSheetState(() => descending = selection.first);
                  },
                ),
                const SizedBox(height: AppSpacing.space4),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop((selectedField, descending)),
                  child: const Text('정렬 적용'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _sortField = result.$1;
      _descending = result.$2;
    });
  }
}

class _MembersSummary extends StatelessWidget {
  const _MembersSummary({required this.members});

  final List<GuildMember> members;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final staffCount = members
        .where(
          (member) =>
              member.role == UserRole.master || member.role == UserRole.admin,
        )
        .length;
    return AppCard(
      emphasized: true,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Icon(
                Icons.groups_rounded,
                color: scheme.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('우리 길드', style: AppTextStyles.cardTitle),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '장비와 스킬 현황을 한눈에 확인하세요',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${members.length}명', style: AppTextStyles.sectionTitle),
              Text('운영진 $staffCount명', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonLegend extends StatelessWidget {
  const _ComparisonLegend({required this.mode});

  final MemberViewMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    final equipmentItems = <Widget>[
      _EquipmentGradeTag(
        equipment: const MemberEquipment(value: '장비', grade: 'none'),
      ),
      _EquipmentGradeTag(
        equipment: const MemberEquipment(value: '장비', grade: 'hero'),
      ),
      _EquipmentGradeTag(
        equipment: const MemberEquipment(value: '장비', grade: 'legend'),
      ),
      _EquipmentGradeTag(
        equipment: const MemberEquipment(value: '장비', grade: 'mythic'),
      ),
      _EquipmentGradeTag(equipment: const MemberEquipment()),
    ];
    final skillItems = <Widget>[
      _SkillTierTag(skillName: '영웅 1'),
      _SkillTierTag(skillName: '전설 1'),
      StatusTag(
        label: '습득 완료',
        icon: Icons.check_circle_outline_rounded,
        foregroundColor: palette.success,
        backgroundColor: palette.successSoft,
      ),
      StatusTag(
        label: '미습득',
        icon: Icons.remove_circle_outline_rounded,
        foregroundColor: scheme.onSurfaceVariant,
        backgroundColor: palette.surfaceSubtle,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('색상 안내', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.space2),
        _LegendRow(
          label: mode == MemberViewMode.equipment ? '등급' : '분류',
          children: mode == MemberViewMode.equipment
              ? equipmentItems
              : skillItems.take(2).toList(),
        ),
        if (mode == MemberViewMode.skill) ...<Widget>[
          const SizedBox(height: AppSpacing.space2),
          _LegendRow(label: '상태', children: skillItems.skip(2).toList()),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 34,
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(label, style: AppTextStyles.caption),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.rank,
    required this.isMe,
    required this.viewMode,
    required this.equipmentPart,
    required this.skillGroup,
    required this.skillName,
  });

  final GuildMember member;
  final int rank;
  final bool isMe;
  final MemberViewMode viewMode;
  final String equipmentPart;
  final MemberSkillGroup skillGroup;
  final String skillName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return AppCard(
      onTap: () => context.push('/members/${member.id}'),
      borderColor: isMe ? scheme.primary.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 21,
                backgroundColor: rank <= 3
                    ? palette.primarySoft
                    : palette.surfaceSubtle,
                foregroundColor: rank <= 3
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                child: Text('$rank', style: AppTextStyles.bodyStrong),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(member.nickname, style: AppTextStyles.cardTitle),
                        _RoleTag(role: member.role),
                        if (isMe)
                          StatusTag(
                            label: '나',
                            foregroundColor: palette.success,
                            backgroundColor: palette.successSoft,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      member.characterSummary,
                      style: AppTextStyles.label.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('전투력', style: AppTextStyles.caption),
                  Text(
                    NumberFormat.decimalPattern().format(member.combatPower),
                    style: AppTextStyles.bodyStrong,
                  ),
                ],
              ),
              MemberManagementMenu(member: member),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          switch (viewMode) {
            MemberViewMode.character => _CharacterComparison(member: member),
            MemberViewMode.equipment => _EquipmentComparison(
              member: member,
              part: equipmentPart,
            ),
            MemberViewMode.skill => _SkillComparison(
              member: member,
              group: skillGroup,
              skillName: skillName,
            ),
          },
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '장비 ${member.enteredEquipmentCount}/13 · 스킬 ${member.learnedSkillCount}/12',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text('상세 보기', style: AppTextStyles.label),
              const SizedBox(width: AppSpacing.space1),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterComparison extends StatelessWidget {
  const _CharacterComparison({required this.member});

  final GuildMember member;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    final alternate = member.alternateCharacter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (alternate != null) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.primarySoft.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(AppRadii.tag),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.switch_account_outlined,
                    size: 17,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      '부계정  ${alternate.characterName} · ${alternate.mainClass}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space2,
            ),
            child: Row(
              children: <Widget>[
                _StatValue(label: '치확', value: member.maxCritRate),
                _StatValue(label: '치저', value: member.maxCritResist),
                _StatValue(label: '상적/충적', value: member.statusEffectAccuracy),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EquipmentComparison extends StatelessWidget {
  const _EquipmentComparison({required this.member, required this.part});

  final GuildMember member;
  final String part;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final equipment = member.equipment[part] ?? const MemberEquipment();
    final gradeColors = _equipmentGradeColors(context, equipment);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: gradeColors.background,
                borderRadius: BorderRadius.circular(AppRadii.tag),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: Icon(
                  part == '무기' ? Icons.gavel_rounded : Icons.shield_outlined,
                  color: gradeColors.foreground,
                  size: 21,
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
                      Text(part, style: AppTextStyles.caption),
                      const SizedBox(width: AppSpacing.space2),
                      _EquipmentGradeTag(equipment: equipment),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    equipment.isEmpty ? '미입력' : equipment.value,
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

class _SkillComparison extends StatelessWidget {
  const _SkillComparison({
    required this.member,
    required this.group,
    required this.skillName,
  });

  final GuildMember member;
  final MemberSkillGroup group;
  final String skillName;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final skills = group == MemberSkillGroup.active
        ? member.activeSkills
        : member.passiveSkills;
    final level = skills[skillName] ?? 'X';
    final learned = level != 'X';
    final tierColors = _skillTierColors(context, skillName);
    final statusColors = _skillStatusColors(context, learned);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: learned
              ? tierColors.foreground.withValues(alpha: 0.52)
              : palette.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: tierColors.background,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space2),
                child: Icon(
                  learned
                      ? Icons.auto_awesome_rounded
                      : Icons.auto_awesome_outlined,
                  color: tierColors.foreground,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.space2,
                    runSpacing: AppSpacing.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(group.label, style: AppTextStyles.caption),
                      _SkillTierTag(skillName: skillName),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Row(
                    children: <Widget>[
                      Icon(
                        learned
                            ? Icons.check_circle_outline_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: statusColors.foreground,
                      ),
                      const SizedBox(width: AppSpacing.space1),
                      Text(
                        learned ? '습득 완료' : '미습득',
                        style: AppTextStyles.label.copyWith(
                          color: statusColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              level,
              style: AppTextStyles.cardTitle.copyWith(
                color: learned ? tierColors.foreground : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentGradeTag extends StatelessWidget {
  const _EquipmentGradeTag({required this.equipment});

  final MemberEquipment equipment;

  @override
  Widget build(BuildContext context) {
    final label = equipment.isEmpty
        ? '미입력'
        : CharacterOptions.equipmentGrades[equipment.grade] ?? '일반';
    final colors = _equipmentGradeColors(context, equipment);
    return StatusTag(
      label: label,
      icon: equipment.isEmpty
          ? Icons.remove_circle_outline_rounded
          : Icons.circle,
      foregroundColor: colors.foreground,
      backgroundColor: colors.background,
    );
  }
}

class _SkillTierTag extends StatelessWidget {
  const _SkillTierTag({required this.skillName});

  final String skillName;

  @override
  Widget build(BuildContext context) {
    final colors = _skillTierColors(context, skillName);
    return StatusTag(
      label: skillName.startsWith('영웅') ? '영웅' : '전설',
      foregroundColor: colors.foreground,
      backgroundColor: colors.background,
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text('${_decimal(value)}%', style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    final (foreground, background) = switch (role) {
      UserRole.master => (palette.warning, palette.warningSoft),
      UserRole.admin => (scheme.primary, palette.primarySoft),
      _ => (scheme.onSurfaceVariant, palette.surfaceSubtle),
    };
    return StatusTag(
      label: role.label,
      foregroundColor: foreground,
      backgroundColor: background,
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<String>('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _MembersLoadingView extends StatelessWidget {
  const _MembersLoadingView();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space3),
      itemBuilder: (context, index) => AppCard(
        child: SizedBox(
          height: index == 0 ? 76 : 180,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: index == 0 ? 180 : double.infinity,
              height: 18,
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.tag),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _decimal(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

({Color foreground, Color background}) _equipmentGradeColors(
  BuildContext context,
  MemberEquipment equipment,
) {
  final palette = context.appPalette;
  final scheme = Theme.of(context).colorScheme;
  if (equipment.isEmpty) {
    return (
      foreground: scheme.onSurfaceVariant,
      background: palette.surfaceSubtle,
    );
  }
  return switch (equipment.grade) {
    'hero' => (
      foreground: palette.bossFixed,
      background: palette.bossFixedSoft,
    ),
    'legend' => (foreground: palette.warning, background: palette.warningSoft),
    'mythic' => (foreground: palette.danger, background: palette.dangerSoft),
    _ => (foreground: palette.bossMain, background: palette.bossMainSoft),
  };
}

({Color foreground, Color background}) _skillTierColors(
  BuildContext context,
  String skillName,
) {
  final palette = context.appPalette;
  return skillName.startsWith('영웅')
      ? (foreground: palette.bossFixed, background: palette.bossFixedSoft)
      : (foreground: palette.warning, background: palette.warningSoft);
}

({Color foreground, Color background}) _skillStatusColors(
  BuildContext context,
  bool learned,
) {
  final palette = context.appPalette;
  final scheme = Theme.of(context).colorScheme;
  return learned
      ? (foreground: palette.success, background: palette.successSoft)
      : (
          foreground: scheme.onSurfaceVariant,
          background: palette.surfaceSubtle,
        );
}
