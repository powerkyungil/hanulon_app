import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/more/presentation/more_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('닉네임 카드를 선택하면 내 정보 화면으로 이동한다', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('more-profile-summary')),
    );
    await tester.pumpAndSettle();

    expect(find.text('내 정보 화면'), findsOneWidget);
  });

  testWidgets('내 정보 열기 버튼을 선택해도 내 정보 화면으로 이동한다', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('내 정보 화면'), findsOneWidget);
  });
}

Widget _buildApp(GoRouter router) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(_FakeAuthController.new)],
    child: MaterialApp.router(theme: AppTheme.iconPurple, routerConfig: router),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/more',
    routes: <RouteBase>[
      GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('내 정보 화면')),
      ),
    ],
  );
}

class _FakeAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'test-token',
      userId: 1,
      username: 'tester',
      nickname: '테스터',
      role: UserRole.member,
    );
  }
}
