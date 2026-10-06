import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env.dart';
import '../core/permissions/role_guard.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/bootstrap/presentation/bootstrap_screen.dart';
import '../features/boss_vote/presentation/boss_vote_screen.dart';
import '../features/deputy/presentation/deputy_accounts_screen.dart';
import '../features/deputy/presentation/deputy_character_selection_screen.dart';
import '../features/deputy/presentation/deputy_login_screen.dart';
import '../features/collections/presentation/collections_screen.dart';
import '../features/content_groups/presentation/content_groups_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/members/presentation/member_detail_screen.dart';
import '../features/members/presentation/members_screen.dart';
import '../features/notice/presentation/notice_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/schedule/presentation/schedule_create_screen.dart';
import '../features/settings/presentation/master_settings_screen.dart';
import '../features/siege/presentation/siege_screen.dart';
import '../features/support/presentation/support_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Do not rebuild the entire router when auth restoration only changes its
  // loading/error state. BootstrapScreen starts restoration from the initial
  // route, so rebuilding here would create another BootstrapScreen and start
  // restoration again in a loop. The router only needs to react when the
  // actual session value changes.
  final session = ref.watch(
    authControllerProvider.select((state) => state.value),
  );
  return GoRouter(
    initialLocation: AppEnvironment.initialLocation,
    redirect: (_, state) => _redirectForSession(session, state.uri.path),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'bootstrap',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const BootstrapScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/deputy-login',
        name: 'deputyLogin',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const DeputyLoginScreen()),
      ),
      GoRoute(
        path: '/deputy/characters',
        name: 'deputyCharacters',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const DeputyCharacterSelectionScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (_, state) => _noTransitionPage(
          state,
          RegisterScreen(inviteCode: state.uri.queryParameters['code'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: '/members',
        name: 'members',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const MembersScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: ':memberId',
            name: 'memberDetail',
            pageBuilder: (_, state) => _noTransitionPage(
              state,
              MemberDetailScreen(
                memberId:
                    int.tryParse(state.pathParameters['memberId'] ?? '') ?? 0,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/schedule/create',
        name: 'scheduleCreate',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const ScheduleCreateScreen()),
      ),
      GoRoute(
        path: '/notices',
        name: 'notices',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const NoticeScreen()),
      ),
      GoRoute(
        path: '/collections',
        name: 'collections',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const CollectionsScreen()),
      ),
      GoRoute(
        path: '/content-groups',
        name: 'contentGroups',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const ContentGroupsScreen()),
      ),
      GoRoute(
        path: '/siege',
        name: 'siege',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const SiegeScreen()),
      ),
      GoRoute(
        path: '/support',
        name: 'support',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const SupportScreen()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const MasterSettingsScreen()),
      ),
      GoRoute(
        path: '/deputy-accounts',
        name: 'deputyAccounts',
        pageBuilder: (_, state) =>
            _noTransitionPage(state, const DeputyAccountsScreen()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, navigationShell) => _noTransitionPage(
          state,
          AppShell(navigationShell: navigationShell),
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                name: 'home',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/schedule',
                name: 'schedule',
                pageBuilder: (_, state) => _noTransitionPage(
                  state,
                  ScheduleScreen(
                    key: ValueKey<String>(state.uri.toString()),
                    targetBossDefinitionId: int.tryParse(
                      state.uri.queryParameters['bossDefinitionId'] ?? '',
                    ),
                    targetSpawnTime: int.tryParse(
                      state.uri.queryParameters['spawnTime'] ?? '',
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/boss-vote',
                name: 'bossVote',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const BossVoteScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/more',
                name: 'more',
                pageBuilder: (_, state) =>
                    _noTransitionPage(state, const MoreScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String? _redirectForSession(Session? session, String path) {
  final isPublic =
      path == '/' ||
      path == '/login' ||
      path == '/deputy-login' ||
      path == '/register';
  if (session == null) return isPublic ? null : '/login';

  if (path == '/' ||
      path == '/login' ||
      path == '/deputy-login' ||
      path == '/register') {
    return session.isDeputy && session.activeCharacter == null
        ? '/deputy/characters'
        : '/home';
  }

  if (!session.isDeputy && path == '/deputy/characters') return '/home';
  if (session.isDeputy &&
      session.activeCharacter == null &&
      path != '/deputy/characters') {
    return '/deputy/characters';
  }

  if (session.isDeputy && _deputyForbiddenPath(path)) return '/home';
  if (path == '/settings' && !RoleGuard.isMaster(session.role)) return '/home';
  if (path == '/deputy-accounts' &&
      !RoleGuard.canManageDeputyAccounts(session.role)) {
    return '/home';
  }
  return null;
}

bool _deputyForbiddenPath(String path) {
  return path == '/profile' ||
      path == '/members' ||
      path.startsWith('/members/') ||
      path == '/notices' ||
      path == '/collections' ||
      path == '/siege' ||
      path == '/schedule/create' ||
      path == '/deputy-accounts';
}

Page<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
