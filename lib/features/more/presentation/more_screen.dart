import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/privacy_policy_button.dart';
import '../../../core/permissions/role_guard.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const _operations = <_MenuItem>[
    _MenuItem(
      Icons.campaign_outlined,
      '공지',
      '길드룰, 가격표와 보스 통제',
      route: '/notices',
    ),
    _MenuItem(
      Icons.volunteer_activism_outlined,
      '손지원',
      '요청과 지원 매칭',
      route: '/support',
      deputyAllowed: true,
      deputyPermission: 'SUPPORT_MATCHING',
    ),
    _MenuItem(
      Icons.inventory_2_outlined,
      '아이템 현황',
      '컬렉션 완료와 분배 우선순위',
      route: '/collections',
    ),
    _MenuItem(
      Icons.account_tree_outlined,
      '콘텐츠 참여',
      '길드원 그룹 편성',
      route: '/content-groups',
      deputyAllowed: true,
      deputyPermission: 'CONTENT_PARTICIPATION_READ',
    ),
    _MenuItem(Icons.diamond_outlined, '공성전', '다이아 사용 현황', route: '/siege'),
  ];

  static const _guild = <_MenuItem>[
    _MenuItem(Icons.groups_outlined, '길드원', '장비와 전투력 확인', route: '/members'),
    _MenuItem(
      Icons.person_outline_rounded,
      '내 정보',
      '캐릭터와 계정 정보',
      route: '/profile',
    ),
    _MenuItem(
      Icons.settings_outlined,
      '마스터 설정',
      '길드 설정과 가입 코드',
      route: '/settings',
      masterOnly: true,
    ),
    _MenuItem(
      Icons.badge_outlined,
      '부주 계정',
      '길드 공용 계정 관리',
      route: '/deputy-accounts',
      staffOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final nickname = session?.nickname.trim();
    final displayName = nickname == null || nickname.isEmpty ? '길드원' : nickname;
    final roleLabel = session?.role.label ?? '길드원';
    final isDeputy = session?.isDeputy == true;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final guildItems = _guild
        .where(
          (item) =>
              (!item.masterOnly ||
                  RoleGuard.canManageGuildSettings(
                    session?.role ?? UserRole.unknown,
                  )) &&
              (!item.staffOnly ||
                  RoleGuard.canManageDeputyAccounts(
                    session?.role ?? UserRole.unknown,
                  )) &&
              !isDeputy,
        )
        .toList();
    final operationItems = _operations
        .where(
          (item) =>
              (!isDeputy || item.deputyAllowed) &&
              (session == null ||
                  item.deputyPermission == null ||
                  session.hasPermission(item.deputyPermission!)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('전체')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.floatingNavigationClearance,
        ),
        children: <Widget>[
          AppCard(
            key: const ValueKey<String>('more-profile-summary'),
            emphasized: true,
            onTap: () =>
                context.push(isDeputy ? '/deputy/characters' : '/profile'),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: palette.primarySoft,
                  foregroundColor: scheme.primary,
                  child: const Icon(Icons.person_rounded),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('$displayName님', style: AppTextStyles.cardTitle),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        isDeputy
                            ? 'DEPUTY · $roleLabel'
                            : '${session?.role.apiValue ?? 'MEMBER'} · $roleLabel',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(
                    isDeputy ? '/deputy/characters' : '/profile',
                  ),
                  tooltip: isDeputy ? '사용 캐릭터 변경' : '내 정보 열기',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          const Text('길드 운영', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.space3),
          _MenuGroup(items: operationItems),
          const SizedBox(height: AppSpacing.space6),
          const Text('계정과 길드', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.space3),
          _MenuGroup(items: guildItems),
          const SizedBox(height: AppSpacing.space6),
          const Text('화면 테마', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.space3),
          const _ThemeSelector(),
          const SizedBox(height: AppSpacing.space4),
          const PrivacyPolicyButton(),
          TextButton(
            onPressed: () => _logout(context, ref),
            child: Text('로그아웃', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '로그아웃할까요?',
      message: '다시 이용하려면 아이디와 비밀번호를 입력해야 합니다.',
      confirmLabel: '로그아웃',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.indexed.map((entry) {
          final (index, item) = entry;
          return Column(
            children: <Widget>[
              ListTile(
                minTileHeight: 68,
                leading: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(item.icon, color: scheme.primary, size: 21),
                  ),
                ),
                title: Text(item.title, style: AppTextStyles.bodyStrong),
                subtitle: Text(item.subtitle, style: AppTextStyles.caption),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () {
                  if (item.route != null) {
                    context.push(item.route!);
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.title} 화면은 순서대로 구현합니다.')),
                  );
                },
              ),
              if (index < items.length - 1)
                const Divider(indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(themeControllerProvider).value ?? AppThemeVariant.iconPurple;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        children: AppThemeVariant.values.indexed.map((entry) {
          final (index, variant) = entry;
          final isSelected = selected == variant;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < AppThemeVariant.values.length - 1
                  ? AppSpacing.space2
                  : 0,
            ),
            child: Semantics(
              selected: isSelected,
              button: true,
              child: InkWell(
                onTap: () => ref
                    .read(themeControllerProvider.notifier)
                    .setVariant(variant),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _ThemeSwatch(variant: variant),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              variant.label,
                              style: AppTextStyles.bodyStrong,
                            ),
                            const SizedBox(height: AppSpacing.space1),
                            Text(
                              variant.description,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.variant});

  final AppThemeVariant variant;

  @override
  Widget build(BuildContext context) {
    final swatch = switch (variant) {
      AppThemeVariant.iconPurple => (
        colors: <Color>[
          AppColors.iconPurpleBackgroundTop,
          AppColors.iconPurpleBackground,
        ],
        border: AppColors.iconPurplePrimary,
        dot: AppColors.iconPurplePrimary,
      ),
      AppThemeVariant.sandGold => (
        colors: <Color>[AppColors.sandBackgroundTop, AppColors.sandBackground],
        border: AppColors.sandPrimary,
        dot: AppColors.sandPrimary,
      ),
      AppThemeVariant.darkBlue => (
        colors: <Color>[AppColors.darkBackgroundTop, AppColors.darkBackground],
        border: AppColors.darkPrimary,
        dot: AppColors.darkPrimary,
      ),
    };

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: swatch.colors,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: swatch.border, width: 2),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: swatch.dot, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(
    this.icon,
    this.title,
    this.subtitle, {
    this.route,
    this.masterOnly = false,
    this.staffOnly = false,
    this.deputyAllowed = false,
    this.deputyPermission,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final bool masterOnly;
  final bool staffOnly;
  final bool deputyAllowed;
  final String? deputyPermission;
}
