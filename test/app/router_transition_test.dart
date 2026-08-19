import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:odin_guild_app/app/router.dart';

void main() {
  test('모든 화면 라우트는 잔상을 방지하는 무전환 페이지를 사용한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    for (final route in _allRoutes(router.configuration.routes)) {
      if (route case final GoRoute goRoute) {
        expect(
          goRoute.pageBuilder,
          isNotNull,
          reason: '${goRoute.path} 라우트에 기본 화면 전환이 남아 있습니다.',
        );
      }
      if (route case final StatefulShellRoute shellRoute) {
        expect(
          shellRoute.pageBuilder,
          isNotNull,
          reason: '앱 셸 라우트에 기본 화면 전환이 남아 있습니다.',
        );
      }
    }
  });
}

Iterable<RouteBase> _allRoutes(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    yield route;
    yield* _allRoutes(route.routes);
  }
}
