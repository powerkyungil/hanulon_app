import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/storage/session_metadata_storage.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/data/auth_repository.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/profile_update_request.dart';
import 'package:odin_guild_app/features/auth/domain/profile_settings.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';
import 'package:odin_guild_app/features/auth/domain/user_profile.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/deputy/data/deputy_auth_repository.dart';
import 'package:odin_guild_app/features/deputy/domain/deputy_account.dart';
import 'package:odin_guild_app/features/deputy/domain/deputy_character.dart';
import 'package:odin_guild_app/features/push_notifications/application/push_notification_service.dart';

void main() {
  group('AuthController', () {
    test('로그인 응답의 사용자 정보와 토큰을 세션에 저장한다', () async {
      final storage = _FakeTokenStorage();
      final repository = _FakeAuthRepository();
      final pushLifecycle = _FakePushTokenLifecycle();
      final container = _createContainer(
        storage,
        repository,
        pushLifecycle: pushLifecycle,
      );
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
      expect(pushLifecycle.registrationCount, 1);
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
      final pushLifecycle = _FakePushTokenLifecycle();
      final container = _createContainer(
        storage,
        repository,
        pushLifecycle: pushLifecycle,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .restoreSession();

      expect(session?.userId, 7);
      expect(session?.nickname, '프레이야');
      expect(session?.accessToken, storage.token);
      expect(pushLifecycle.registrationCount, 1);
    });

    test('부주 로그인 후 캐릭터 선택을 별도 세션으로 저장한다', () async {
      final storage = _FakeTokenStorage();
      final deputyRepository = _FakeDeputyAuthRepository();
      final metadataStorage = _FakeSessionMetadataStorage();
      final container = _createContainer(
        storage,
        _FakeAuthRepository(),
        deputyRepository: deputyRepository,
        metadataStorage: metadataStorage,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .loginAsDeputy(
            username: 'shared-deputy',
            password: 'password',
            autoLogin: true,
          );

      expect(session.isDeputy, isTrue);
      expect(session.activeCharacter, isNull);
      expect(storage.token, 'deputy-token');
      expect(storage.persist, isTrue);
      expect(metadataStorage.value?.isDeputy, isTrue);

      final selected = await container
          .read(authControllerProvider.notifier)
          .selectDeputyCharacter('MAIN:7');

      expect(selected?.characterKey, 'MAIN:7');
      expect(
        container.read(authControllerProvider).value?.activeCharacterKey,
        'MAIN:7',
      );
      expect(deputyRepository.updatedCharacterKey, 'MAIN:7');
    });

    test('부주 토큰 복원 시 서버의 현재 캐릭터를 다시 조회한다', () async {
      final storage = _FakeTokenStorage()
        ..token = _tokenWithClaims(
          userId: 0,
          username: 'shared-deputy',
          nickname: '공용 부주',
          role: 'DEPUTY',
          extraClaims: <String, dynamic>{
            'principalType': 'DEPUTY',
            'deputyId': 4,
            'guildId': 9,
          },
        );
      final deputyRepository = _FakeDeputyAuthRepository()
        ..activeCharacter = _character('ALTERNATE:7')
        ..nickname = '서버 최신 부주명';
      final container = _createContainer(
        storage,
        _FakeAuthRepository(),
        deputyRepository: deputyRepository,
        metadataStorage: _FakeSessionMetadataStorage(),
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final session = await container
          .read(authControllerProvider.notifier)
          .restoreSession();

      expect(session?.isDeputy, isTrue);
      expect(session?.activeCharacterKey, 'ALTERNATE:7');
      expect(session?.nickname, '서버 최신 부주명');
      expect(deputyRepository.fetchNicknameCount, 1);
      expect(deputyRepository.fetchActiveCharacterCount, 1);
    });

    test('부주 닉네임 변경 후 세션과 저장 메타데이터를 갱신한다', () async {
      final storage = _FakeTokenStorage();
      final deputyRepository = _FakeDeputyAuthRepository();
      final metadataStorage = _FakeSessionMetadataStorage();
      final container = _createContainer(
        storage,
        _FakeAuthRepository(),
        deputyRepository: deputyRepository,
        metadataStorage: metadataStorage,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .loginAsDeputy(
            username: 'shared-deputy',
            password: 'password',
            autoLogin: true,
          );
      await container
          .read(authControllerProvider.notifier)
          .updateDeputyNickname('새 부주명');

      expect(container.read(authControllerProvider).value?.nickname, '새 부주명');
      expect(metadataStorage.value?.nickname, '새 부주명');
      expect(deputyRepository.updatedNickname, '새 부주명');
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
      final pushLifecycle = _FakePushTokenLifecycle();
      final container = _createContainer(
        storage,
        repository,
        pushLifecycle: pushLifecycle,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(storage.token, isNull);
      expect(container.read(authControllerProvider).value, isNull);
      expect(pushLifecycle.removalCount, 1);
    });

    test('회원 탈퇴가 성공하면 비밀번호를 전달하고 토큰과 세션을 비운다', () async {
      final storage = _FakeTokenStorage()..token = 'saved-token';
      final repository = _FakeAuthRepository();
      final container = _createContainer(storage, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .deleteAccount(password: 'current-password');

      expect(repository.deletedWithPassword, 'current-password');
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
  Map<String, dynamic>? extraClaims,
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
            ...?extraClaims,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

ProviderContainer _createContainer(
  TokenStorage storage,
  AuthRepository repository, {
  PushTokenLifecycle? pushLifecycle,
  DeputyAuthRepository? deputyRepository,
  SessionMetadataStorage? metadataStorage,
}) {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
      if (deputyRepository != null)
        deputyAuthRepositoryProvider.overrideWithValue(deputyRepository),
      if (metadataStorage != null)
        sessionMetadataStorageProvider.overrideWithValue(metadataStorage),
      pushTokenLifecycleProvider.overrideWithValue(
        pushLifecycle ?? _FakePushTokenLifecycle(),
      ),
    ],
  );
}

class _FakePushTokenLifecycle implements PushTokenLifecycle {
  int registrationCount = 0;
  int removalCount = 0;

  @override
  Future<void> registerAfterAuthentication() async {
    registrationCount++;
  }

  @override
  Future<void> removeBeforeLogout() async {
    removalCount++;
  }
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
  String? deletedWithPassword;

  @override
  Future<void> deleteMe({required String password}) async {
    deletedWithPassword = password;
  }

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
  Future<String?> register(RegistrationRequest request) async => null;

  @override
  Future<void> updateMe(ProfileUpdateRequest request) async {}
}

DeputyCharacter _character(String key) {
  final isAlternate = key.startsWith('ALTERNATE:');
  return DeputyCharacter(
    characterKey: key,
    characterType: isAlternate ? 'ALTERNATE' : 'MAIN',
    ownerUserId: 7,
    ownerNickname: '프레이야',
    characterName: isAlternate ? '프레이야 부캐' : '프레이야',
    mainClass: '헌트리스',
    combatPower: 321000,
  );
}

class _FakeDeputyAuthRepository implements DeputyAuthRepository {
  DeputyCharacter? activeCharacter;
  String? updatedCharacterKey;
  String nickname = '공용 부주';
  String? updatedNickname;
  int fetchNicknameCount = 0;
  int fetchActiveCharacterCount = 0;

  @override
  Future<Session> login({
    required String username,
    required String password,
  }) async {
    return Session(
      accessToken: 'deputy-token',
      userId: 0,
      username: username,
      nickname: '공용 부주',
      role: UserRole.deputy,
      principalType: SessionPrincipalType.deputy,
      deputyId: 4,
      guildId: 9,
      activeCharacter: activeCharacter,
      permissions: const <String>['VOTE_PARTICIPATE'],
    );
  }

  @override
  Future<List<DeputyCharacter>> fetchCharacters() async => <DeputyCharacter>[
    _character('MAIN:7'),
  ];

  @override
  Future<String> fetchNickname() async {
    fetchNicknameCount++;
    return nickname;
  }

  @override
  Future<String> updateNickname(String nickname) async {
    this.nickname = nickname;
    updatedNickname = nickname;
    return nickname;
  }

  @override
  Future<DeputyCharacter?> fetchActiveCharacter() async {
    fetchActiveCharacterCount++;
    return activeCharacter;
  }

  @override
  Future<void> updateActiveCharacter(String characterKey) async {
    updatedCharacterKey = characterKey;
    activeCharacter = _character(characterKey);
  }

  @override
  Future<List<DeputyAccount>> fetchAccounts() async => const <DeputyAccount>[];

  @override
  Future<void> createAccount({
    required String username,
    required String password,
    required String nickname,
  }) async {}

  @override
  Future<void> resetPassword(int accountId, String password) async {}

  @override
  Future<void> setActive(int accountId, bool isActive) async {}
}

class _FakeSessionMetadataStorage implements SessionMetadataStorage {
  Session? value;

  @override
  Future<Session?> read() async => value;

  @override
  Future<void> write(Session session, {required bool persist}) async {
    value = persist ? session : null;
  }

  @override
  Future<void> clear() async => value = null;
}
