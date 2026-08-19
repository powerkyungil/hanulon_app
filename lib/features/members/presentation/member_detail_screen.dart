import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/domain/character_options.dart';
import '../../auth/domain/user_role.dart';
import '../application/members_controller.dart';
import '../domain/guild_member.dart';
import '../domain/member_equipment.dart';
import 'widgets/member_management_menu.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({required this.memberId, super.key});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersControllerProvider);
    final member = members.value == null ? null : _find(members.value!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('길드원 상세'),
        actions: <Widget>[
          if (member != null)
            MemberManagementMenu(member: member, popAfterRemove: true),
        ],
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error is ApiException
              ? error.message
              : '길드원 정보를 불러오지 못했습니다.',
          onRetry: () => ref.invalidate(membersControllerProvider),
        ),
        data: (members) {
          final selected = _find(members);
          if (selected == null) {
            return const ErrorView(
              title: '길드원을 찾을 수 없어요',
              message: '이미 탈퇴했거나 삭제된 길드원일 수 있습니다.',
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(membersControllerProvider.notifier).refreshMembers(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                AppSpacing.space8,
              ),
              children: <Widget>[
                _MemberHero(member: selected),
                const SizedBox(height: AppSpacing.space4),
                _CharacterSection(member: selected),
                const SizedBox(height: AppSpacing.space3),
                _EquipmentSection(member: selected),
                const SizedBox(height: AppSpacing.space3),
                _SkillSection(member: selected),
              ],
            ),
          );
        },
      ),
    );
  }

  GuildMember? _find(List<GuildMember> members) {
    for (final member in members) {
      if (member.id == memberId) return member;
    }
    return null;
  }
}

class _MemberHero extends StatelessWidget {
  const _MemberHero({required this.member});

  final GuildMember member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return AppCard(
      emphasized: true,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 30,
            backgroundColor: palette.primarySoft,
            foregroundColor: scheme.primary,
            child: Text(
              member.nickname.characters.firstOrNull ?? '?',
              style: AppTextStyles.sectionTitle,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.nickname, style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  member.characterSummary,
                  style: AppTextStyles.label.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                _RoleTag(role: member.role),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('전투력', style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                NumberFormat.decimalPattern().format(member.combatPower),
                style: AppTextStyles.cardTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({required this.member});

  final GuildMember member;

  @override
  Widget build(BuildContext context) {
    final alternate = member.alternateCharacter;
    return _DetailSection(
      icon: Icons.person_outline_rounded,
      title: '캐릭터 정보',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _InfoValue(label: '직업', value: member.occupation),
              _InfoValue(label: '주클래스', value: member.mainClass),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              _InfoValue(
                label: '최고 치명타 확률',
                value: '${_decimal(member.maxCritRate)}%',
              ),
              _InfoValue(
                label: '최고 치명타 저항',
                value: '${_decimal(member.maxCritResist)}%',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: <Widget>[
              _InfoValue(
                label: '상적/충적',
                value: '${_decimal(member.statusEffectAccuracy)}%',
              ),
              _InfoValue(
                label: '등록 부계정',
                value: alternate == null ? '없음' : '1개',
              ),
            ],
          ),
          if (alternate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            _AlternateCard(
              name: alternate.characterName,
              mainClass: alternate.mainClass,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.label, required this.value});

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
          Text(
            value.trim().isEmpty ? '-' : value,
            style: AppTextStyles.bodyStrong,
          ),
        ],
      ),
    );
  }
}

class _AlternateCard extends StatelessWidget {
  const _AlternateCard({required this.name, required this.mainClass});

  final String name;
  final String mainClass;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primarySoft.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: <Widget>[
            Icon(Icons.switch_account_outlined, color: scheme.primary),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('부계정', style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text('$name · $mainClass', style: AppTextStyles.bodyStrong),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({required this.member});

  final GuildMember member;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      icon: Icons.shield_outlined,
      title: '장비 정보',
      subtitle: '${member.enteredEquipmentCount}/13부위 입력',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.space2,
              crossAxisSpacing: AppSpacing.space2,
              mainAxisExtent: 86,
            ),
            itemCount: CharacterOptions.equipmentParts.length,
            itemBuilder: (context, index) {
              final part = CharacterOptions.equipmentParts[index];
              return _EquipmentTile(
                part: part,
                equipment: member.equipment[part] ?? const MemberEquipment(),
              );
            },
          );
        },
      ),
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile({required this.part, required this.equipment});

  final String part;
  final MemberEquipment equipment;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final gradeLabel =
        CharacterOptions.equipmentGrades[equipment.grade] ?? '일반';
    final gradeColor = switch (equipment.grade) {
      'hero' => palette.bossFixed,
      'legend' => palette.warning,
      'mythic' => palette.danger,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(part, style: AppTextStyles.caption)),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: gradeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(gradeLabel, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              equipment.isEmpty ? '-' : equipment.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillSection extends StatelessWidget {
  const _SkillSection({required this.member});

  final GuildMember member;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      icon: Icons.auto_awesome_outlined,
      title: '스킬 강화 현황',
      subtitle: '${member.learnedSkillCount}/12개 습득',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SkillGroup(title: '액티브', skills: member.activeSkills),
          const SizedBox(height: AppSpacing.space5),
          _SkillGroup(title: '패시브', skills: member.passiveSkills),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({required this.title, required this.skills});

  final String title;
  final Map<String, String> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        const SizedBox(height: AppSpacing.space3),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.space2,
            crossAxisSpacing: AppSpacing.space2,
            mainAxisExtent: 70,
          ),
          itemCount: CharacterOptions.skillNames.length,
          itemBuilder: (context, index) {
            final name = CharacterOptions.skillNames[index];
            return _SkillTile(name: name, level: skills[name] ?? 'X');
          },
        ),
      ],
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.name, required this.level});

  final String name;
  final String level;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final learned = level != 'X';
    final gradeColor = name.startsWith('영웅')
        ? palette.bossFixed
        : palette.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: learned
            ? gradeColor.withValues(alpha: 0.10)
            : palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: learned
              ? gradeColor.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(name, style: AppTextStyles.caption),
            const Spacer(),
            Text(
              level,
              style: AppTextStyles.bodyStrong.copyWith(
                color: learned ? gradeColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: scheme.primary),
              const SizedBox(width: AppSpacing.space2),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
              if (subtitle != null)
                Text(subtitle!, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.space5),
          child,
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

String _decimal(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
