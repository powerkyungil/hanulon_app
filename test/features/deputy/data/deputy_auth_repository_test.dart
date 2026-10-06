import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/deputy/data/deputy_auth_repository.dart';

void main() {
  test('부주 로그인과 캐릭터 응답을 전용 DTO로 변환한다', () async {
    final client = _client((options, handler) {
      final data = switch (options.path) {
        '/api/v1/deputy-auth/login' => <String, dynamic>{
          'data': <String, dynamic>{
            'token': 'deputy-token',
            'deputyId': 4,
            'guildId': 9,
            'username': 'shared-deputy',
            'nickname': '공용 부주',
            'activeCharacter': null,
            'permissions': <String>['SCHEDULE_PARTICIPATE', 'VOTE_PARTICIPATE'],
          },
        },
        '/api/v1/deputy/characters' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'characterKey': 'MAIN:123',
              'characterType': 'MAIN',
              'ownerUserId': 123,
              'ownerNickname': '프레이야',
              'characterName': '프레이야',
              'mainClass': '헌트리스',
              'combatPower': 321000,
            },
          ],
        },
        '/api/v1/deputy/active-character' => <String, dynamic>{
          'data': <String, dynamic>{
            'characterKey': 'MAIN:123',
            'characterType': 'MAIN',
            'ownerUserId': 123,
            'ownerNickname': '프레이야',
            'characterName': '프레이야',
            'mainClass': '헌트리스',
            'combatPower': 321000,
          },
        },
        '/api/v1/deputy-accounts' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 4,
              'guildId': 9,
              'username': 'shared-deputy',
              'nickname': '공용 부주',
              'isActive': true,
              'activeCharacterKey': 'MAIN:123',
              'createdAt': '2026-10-05T00:00:00.000Z',
            },
          ],
        },
        _ => throw StateError('예상하지 못한 경로: ${options.path}'),
      };
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 200, data: data),
      );
    });

    final repository = ApiDeputyAuthRepository(client);
    final session = await repository.login(
      username: 'shared-deputy',
      password: 'password',
    );
    final characters = await repository.fetchCharacters();
    final active = await repository.fetchActiveCharacter();
    final accounts = await repository.fetchAccounts();

    expect(session.accessToken, 'deputy-token');
    expect(session.role, UserRole.deputy);
    expect(session.isDeputy, isTrue);
    expect(session.deputyId, 4);
    expect(session.guildId, 9);
    expect(session.permissions, <String>[
      'SCHEDULE_PARTICIPATE',
      'VOTE_PARTICIPATE',
    ]);
    expect(characters.single.characterKey, 'MAIN:123');
    expect(active?.displayName, '프레이야');
    expect(accounts.single.activeCharacterKey, 'MAIN:123');
  });

  test('부주 계정 변경 API의 204 응답을 JSON 없이 처리한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 204, data: null),
      );
    });

    final repository = ApiDeputyAuthRepository(client);
    await repository.updateActiveCharacter('ALTERNATE:123');
    await repository.createAccount(
      username: 'night-deputy',
      password: 'password',
      nickname: '야간 부주',
    );
    await repository.resetPassword(4, 'new-password');
    await repository.setActive(4, false);

    expect(requests.map((request) => request.method), <String>[
      'PUT',
      'POST',
      'PUT',
      'PUT',
    ]);
    expect(requests[0].path, '/api/v1/deputy/active-character');
    expect(requests[0].data, <String, String>{'characterKey': 'ALTERNATE:123'});
    expect(requests[1].path, '/api/v1/deputy-accounts');
    expect(requests[1].data, <String, String>{
      'username': 'night-deputy',
      'password': 'password',
      'nickname': '야간 부주',
    });
    expect(requests[2].path, '/api/v1/deputy-accounts/4/password');
    expect(requests[2].data, <String, String>{'password': 'new-password'});
    expect(requests[3].path, '/api/v1/deputy-accounts/4/active');
    expect(requests[3].data, <String, bool>{'isActive': false});
  });
}

ApiClient _client(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final client = ApiClient(
    baseUrl: 'https://example.test',
    tokenStorage: _FakeTokenStorage(),
  );
  client.raw.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return client;
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<void> writeToken(String token, {bool persist = true}) async {}
}
