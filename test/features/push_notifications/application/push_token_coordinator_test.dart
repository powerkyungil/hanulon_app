import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/storage/installation_storage.dart';
import 'package:odin_guild_app/features/push_notifications/application/push_token_coordinator.dart';
import 'package:odin_guild_app/features/push_notifications/data/push_token_repository.dart';

void main() {
  test('로그인 등록과 token refresh가 같은 설치 UUID로 서버를 갱신한다', () async {
    final repository = _FakePushTokenRepository();
    final coordinator = PushTokenCoordinator(
      repository,
      _FakeInstallationStorage(),
    );

    expect(
      await coordinator.registerAfterAuthentication('initial-token'),
      isTrue,
    );
    expect(await coordinator.registerRefreshedToken('refreshed-token'), isTrue);

    expect(repository.registeredTokens, <String>[
      'initial-token',
      'refreshed-token',
    ]);
    expect(repository.deviceIds, <String>[
      'installation-id',
      'installation-id',
    ]);
  });

  test('인증 전 refresh는 등록하지 않고 로그아웃은 현재 토큰을 삭제한다', () async {
    final repository = _FakePushTokenRepository();
    final coordinator = PushTokenCoordinator(
      repository,
      _FakeInstallationStorage(),
    );

    expect(await coordinator.registerRefreshedToken('orphan-token'), isFalse);
    expect(repository.registeredTokens, isEmpty);

    await coordinator.registerAfterAuthentication('current-token');
    await coordinator.removeBeforeLogout('current-token');

    expect(repository.deletedTokens, <String>['current-token']);
    expect(coordinator.isAuthenticated, isFalse);
  });

  test('등록 실패는 false로 반환해 호출자가 로그인과 분리해 재시도할 수 있다', () async {
    final repository = _FakePushTokenRepository()..failRegistration = true;
    final coordinator = PushTokenCoordinator(
      repository,
      _FakeInstallationStorage(),
    );

    expect(
      await coordinator.registerAfterAuthentication('initial-token'),
      isFalse,
    );
    expect(coordinator.isAuthenticated, isTrue);
  });
}

class _FakeInstallationStorage implements InstallationStorage {
  @override
  Future<String> getOrCreateDeviceId() async => 'installation-id';
}

class _FakePushTokenRepository implements PushTokenRepository {
  final List<String> registeredTokens = <String>[];
  final List<String> deviceIds = <String>[];
  final List<String> deletedTokens = <String>[];
  bool failRegistration = false;

  @override
  Future<void> register({
    required String token,
    required String deviceId,
  }) async {
    if (failRegistration) throw StateError('offline');
    registeredTokens.add(token);
    deviceIds.add(deviceId);
  }

  @override
  Future<void> delete({required String token}) async {
    deletedTokens.add(token);
  }
}
