import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/data/auth_repository.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/profile_update_request.dart';
import 'package:odin_guild_app/features/auth/domain/profile_settings.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';
import 'package:odin_guild_app/features/auth/domain/user_profile.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';

void main() {
  group('AuthController', () {
    test('로그인 응답의 사용자 정보와 토큰을 세션에 저장한다', () async {
      final storage = _FakeTokenStorage();
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .login(username: 'odin', password: 'password', autoLogin: false);

      expect(session.nickname, '로그인 닉네임');
      expect(session.role, UserRole.admin);
      expect(storage.token, 'access-token');
      expect(storage.persist, isFalse);
      expect(container.read(authControllerProvider).value, same(session));
    });

    test('저장된 토큰으로 사용자 세션을 복원한다', () async {
      final storage = _FakeTokenStorage()
        ..token = _tokenWithClaims(
          userId: 7,
          username: 'odin_master',
          nickname: '프레이야',
          role: 'MASTER',
        );
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .restoreSession();

      expect(session?.userId, 7);
      expect(session?.nickname, '프레이야');
      expect(session?.accessToken, storage.token);
    });

    test('세션 복원 시 JWT의 로그인 아이디를 읽기 전용 표시값으로 사용한다', () async {
      final storage = _FakeTokenStorage()
        ..token = _tokenWithClaims(
          userId: 7,
          username: 'odin_master',
          nickname: '프레이야',
          role: 'MASTER',
        );
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .restoreSession();

      expect(session?.username, 'odin_master');
    });

    test('로그아웃하면 저장된 토큰과 세션을 비운다', () async {
      final storage = _FakeTokenStorage()..token = 'saved-token';
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(storage.token, isNull);
      expect(container.read(authControllerProvider).value, isNull);
    });

    test('형식이 올바르지 않은 저장 토큰은 삭제하고 로그인 상태로 복원하지 않는다', () async {
      final storage = _FakeTokenStorage()..token = 'not-a-jwt';
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .restoreSession();

      expect(session, isNull);
      expect(storage.token, isNull);
    });

    test('길드장 위임 후 현재 세션 역할을 길드원으로 갱신한다', () async {
      final storage = _FakeTokenStorage();
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(username: 'odin', password: 'password', autoLogin: false);

      container
          .read(authControllerProvider.notifier)
          .updateCurrentRole(UserRole.member);

      expect(
        container.read(authControllerProvider).value?.role,
        UserRole.member,
      );
    });
  });
}

String _tokenWithClaims({
  required int userId,
  required String username,
  required String nickname,
  required String role,
}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'sub': '$userId',
            'username': username,
            'nickname': nickname,
            'role': role,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

ProviderContainer _createContainer(
  TokenStorage storage,
  AuthRepository repository,
) {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeTokenStorage implements TokenStorage {
  String? token;
  bool? persist;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token, {bool persist = true}) async {
    this.token = token;
    this.persist = persist;
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> fetchMe() async {
    return const UserProfile(id: 7, role: UserRole.admin, nickname: '프레이야');
  }

  @override
  Future<ProfileSettings> fetchProfileSettings() async {
    return const ProfileSettings(allowCombatPowerEdit: true);
  }

  @override
  Future<Session> login({
    required String username,
    required String password,
  }) async {
    return Session(
      accessToken: 'access-token',
      userId: 7,
      username: username,
      nickname: '로그인 닉네임',
      role: UserRole.admin,
    );
  }

  @override
  Future<void> register(RegistrationRequest request) async {}

  @override
  Future<void> updateMe(ProfileUpdateRequest request) async {}
}
