import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/time/seoul_datetime.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_hero_card.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../boss_vote/application/boss_vote_controller.dart';
import '../../notice/application/notice_controller.dart';
import '../../notice/domain/notice_article.dart';
import '../../schedule/application/schedule_controller.dart';
import '../../schedule/domain/boss_schedule.dart';
import '../../settings/application/settings_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final nickname = ref.watch(
      authControllerProvider.select(
        (state) => state.value?.nickname.trim() ?? '',
      ),
    );
    final guildName = ref.watch(
      settingsControllerProvider.select(
        (state) => state.value?.guildName.trim() ?? '',
      ),
    );
    final scheduleState = ref.watch(scheduleControllerProvider);
    final voteState = ref.watch(bossVoteControllerProvider);
    final noticeState = ref.watch(noticeOverviewProvider);
    final clock = ref.watch(serverClockProvider);
    final now = clock.now();
    final greetingName = nickname.isEmpty ? '길드원' : nickname;
    final schedules = scheduleState.value?.schedules ?? const <BossSchedule>[];
    final nextBoss = schedules.where((item) {
      return item.spawnTime >= now.millisecondsSinceEpoch;
    }).firstOrNull;
    final todayKey = _dateKey(now.millisecondsSinceEpoch);
    final todayScheduleCount = schedules
        .where((item) => _dateKey(item.spawnTime) == todayKey)
        .length;
    final todayVoteCount =
        voteState.value
            ?.where((item) => _dateKey(item.spawnTime) == todayKey)
            .length ??
        0;
    final firstNotice = noticeState.value?.rules.firstOrNull;
    final dateLabel = DateFormat('M월 d일').format(now);
    final role = session?.role;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(noticeOverviewProvider);
            ref.invalidate(settingsControllerProvider);
            await Future.wait<void>(<Future<void>>[
              ref.read(scheduleControllerProvider.notifier).refresh(),
              ref.read(bossVoteControllerProvider.notifier).refresh(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space5,
              AppSpacing.screenHorizontal,
              AppSpacing.floatingNavigationClearance,
            ),
            children: <Widget>[
              _HomeHeader(
                guildName: guildName,
                greetingName: greetingName,
                dateLabel: dateLabel,
                role: role == UserRole.unknown ? null : role,
              ),
              const SizedBox(height: AppSpacing.space6),
              _NextBossCard(nextBoss: nextBoss, now: now),
              const SizedBox(height: AppSpacing.space6),
              _SectionHeader(title: '오늘의 길드', trailing: dateLabel),
              const SizedBox(height: AppSpacing.space3),
              _GuildSummaryCard(
                scheduleCount: todayScheduleCount,
                voteCount: todayVoteCount,
              ),
              const SizedBox(height: AppSpacing.space6),
              const _SectionHeader(title: '빠른 실행'),
              const SizedBox(height: AppSpacing.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.calendar_month_rounded,
                      label: '일정 보기',
                      description: '보스 일정 확인',
                      onTap: () => context.go('/schedule'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.how_to_vote_rounded,
                      label: '투표 참여',
                      description: '오늘 투표 확인',
                      onTap: () => context.go('/boss-vote'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              _SectionHeader(
                title: '공지사항',
                actionLabel: '전체보기',
                onAction: () => context.push('/notices'),
              ),
              const SizedBox(height: AppSpacing.space2),
              _NoticeCard(
                notice: firstNotice,
                onTap: () => context.push('/notices'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dateKey(int milliseconds) {
    return DateFormat(
      'yyyy-MM-dd',
    ).format(SeoulDateTime.fromEpochMilliseconds(milliseconds));
  }

  static String _noticePreview(String content) {
    return content
        .replaceAll(r'\n', ' ')
        .replaceAll('>', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.guildName,
    required this.greetingName,
    required this.dateLabel,
    required this.role,
  });

  final String guildName;
  final String greetingName;
  final String dateLabel;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (guildName.isNotEmpty) ...<Widget>[
                Text(
                  guildName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
              ],
              Text(
                '안녕하세요, $greetingName님',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pageTitle,
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    dateLabel,
                    style: AppTextStyles.label.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (role case final role?) ...<Widget>[
                    const SizedBox(width: AppSpacing.space2),
                    _RolePill(role: role),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        const _BrandMark(),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: palette.cardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.control - 1),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(
              color: palette.primarySoft,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.auto_awesome_rounded, color: palette.accent),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.tag),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          role.label,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Text(title, style: AppTextStyles.sectionTitle),
        if (trailing case final trailing?) ...<Widget>[
          const Spacer(),
          Text(
            trailing,
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (actionLabel case final actionLabel?) ...<Widget>[
          const Spacer(),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ],
    );
  }
}

class _NextBossCard extends StatelessWidget {
  const _NextBossCard({required this.nextBoss, required this.now});

  final BossSchedule? nextBoss;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final schedule = nextBoss;
    final colors = schedule == null ? null : _tagColors(context, schedule.type);

    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    Icons.track_changes_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '오늘의 포커스',
                style: AppTextStyles.label.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (colors case final colors?) ...<Widget>[
                const Spacer(),
                StatusTag(
                  label: schedule!.type,
                  foregroundColor: colors.$1,
                  backgroundColor: colors.$2,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '다음 보스',
            style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (schedule == null) ...<Widget>[
            const Text('예정된 일정이 없어요', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space2),
            Text(
              '일정 탭에서 새로고침하거나 운영진에게 확인해 주세요.',
              style: AppTextStyles.body.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space5),
            AppButton(
              label: '일정 확인',
              icon: Icons.calendar_month_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/schedule'),
            ),
          ] else ...<Widget>[
            _NextBossDetails(schedule: schedule, now: now),
            const SizedBox(height: AppSpacing.space4),
            AppButton(
              label: '일정에서 확인',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/schedule'),
              expand: true,
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _tagColors(BuildContext context, String type) {
    final palette = context.appPalette;
    return switch (type) {
      '본섭' => (palette.bossMain, palette.bossMainSoft),
      '침공' => (palette.bossInvasion, palette.bossInvasionSoft),
      '공통' => (palette.bossCommon, palette.bossCommonSoft),
      _ => (palette.bossFixed, palette.bossFixedSoft),
    };
  }
}

class _NextBossDetails extends StatelessWidget {
  const _NextBossDetails({required this.schedule, required this.now});

  final BossSchedule schedule;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = Duration(
      milliseconds: schedule.spawnTime - now.millisecondsSinceEpoch,
    );
    final countdownColor = remaining <= const Duration(minutes: 5)
        ? context.appPalette.warning
        : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                schedule.boss,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '남은 시간',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  _remainingLabel(remaining),
                  style: AppTextStyles.countdown.copyWith(
                    color: countdownColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.space1),
                Text(
                  '${SeoulDateTime.formatTime(schedule.spawnTime)} · ${schedule.region}',
                  style: AppTextStyles.label.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _remainingLabel(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes.remainder(60)}분';
    }
    if (duration.inMinutes <= 0) return '곧 시작';
    return '${duration.inMinutes.clamp(0, 999)}분 남음';
  }
}

class _GuildSummaryCard extends StatelessWidget {
  const _GuildSummaryCard({
    required this.scheduleCount,
    required this.voteCount,
  });

  final int scheduleCount;
  final int voteCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryMetric(
              icon: Icons.calendar_month_outlined,
              label: '오늘 일정',
              value: '$scheduleCount개',
            ),
          ),
          Container(width: 1, height: 48, color: palette.cardBorder),
          Expanded(
            child: _SummaryMetric(
              icon: Icons.how_to_vote_outlined,
              label: '오늘 투표',
              value: '$voteCount개',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      child: Row(
        children: <Widget>[
          _IconBadge(
            icon: icon,
            backgroundColor: palette.primarySoft,
            foregroundColor: scheme.primary,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(value, style: AppTextStyles.cardTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconBadge(
                icon: icon,
                backgroundColor: palette.primarySoft,
                foregroundColor: scheme.primary,
                size: 36,
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(label, style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.space1),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});

  final NoticeArticle? notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    final article = notice;
    final updatedAt = article?.updatedAt;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _IconBadge(
            icon: Icons.campaign_outlined,
            backgroundColor: palette.primarySoft,
            foregroundColor: scheme.primary,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        article?.title ?? '등록된 공지가 없어요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    if (updatedAt case final updatedAt?) ...<Widget>[
                      const SizedBox(width: AppSpacing.space2),
                      Text(
                        DateFormat('M.d').format(updatedAt),
                        style: AppTextStyles.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  article == null
                      ? '새 공지가 등록되면 여기에 표시됩니다.'
                      : HomeScreen._noticePreview(article.content),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 36,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: 20, color: foregroundColor),
      ),
    );
  }
}
