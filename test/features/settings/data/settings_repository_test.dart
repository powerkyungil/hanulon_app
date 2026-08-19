import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/settings/data/settings_repository.dart';
import 'package:odin_guild_app/features/settings/domain/guild_settings.dart';

void main() {
  test('v1 길드 설정을 조회하고 변경한다', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    late RequestOptions settingsRequest;
    Map<String, dynamic>? savedBody;
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET') {
            settingsRequest = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'data': <String, dynamic>{
                    'guildName': '오딘 길드',
                    'allowMemberCombatPowerEdit': true,
                  },
                },
              ),
            );
            return;
          }
          expect(options.method, 'PUT');
          expect(options.path, '/api/v1/guild/settings');
          savedBody = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response<Object?>(requestOptions: options, statusCode: 204),
          );
        },
      ),
    );
    final repository = ApiSettingsRepository(client);

    await repository.fetchSettings();
    await repository.saveSettings(
      const GuildSettings(guildName: '새 길드', allowMemberCombatPowerEdit: false),
    );

    expect(settingsRequest.method, 'GET');
    expect(settingsRequest.path, '/api/v1/guild/settings');
    expect(savedBody?['guildName'], '새 길드');
    expect(savedBody?['allowMemberCombatPowerEdit'], false);
    expect(savedBody?.containsKey('discord_token'), isFalse);
  });

  test('가입 API 응답을 고정 가입 코드로 변환한다', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'inviteCode': 'invite-code',
                  'role': 'ADMIN',
                },
              },
            ),
          );
        },
      ),
    );

    final invite = await ApiSettingsRepository(
      client,
    ).createInvite(UserRole.admin);

    expect(invite.role, UserRole.admin);
    expect(invite.code, 'invite-code');
  });

  test('현재 역할별 고정 가입 코드를 조회한다', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'GET');
          expect(options.path, '/api/v1/auth/invites');
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <Map<String, String>>[
                  <String, String>{'inviteCode': 'APPLE123', 'role': 'MEMBER'},
                  <String, String>{'inviteCode': 'ADMIN123', 'role': 'ADMIN'},
                ],
              },
            ),
          );
        },
      ),
    );

    final invites = await ApiSettingsRepository(client).fetchInvites();

    expect(invites.map((invite) => invite.code), <String>[
      'APPLE123',
      'ADMIN123',
    ]);
    expect(invites.map((invite) => invite.role), <UserRole>[
      UserRole.member,
      UserRole.admin,
    ]);
  });

  test('마스터가 입력한 커스텀 고정 가입 코드를 저장 요청에 전달한다', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    Map<String, dynamic>? requestBody;
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'inviteCode': 'ODIN-2026',
                  'role': 'MEMBER',
                },
              },
            ),
          );
        },
      ),
    );

    await ApiSettingsRepository(
      client,
    ).createInvite(UserRole.member, customCode: '  ODIN-2026  ');

    expect(requestBody, <String, dynamic>{
      'targetRole': 'MEMBER',
      'customCode': 'ODIN-2026',
    });
  });

  test('현재 코드 없이 저장하면 서버가 새 랜덤 코드를 생성하도록 요청한다', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    Map<String, dynamic>? requestBody;
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'inviteCode': 'RANDOM-CODE',
                'role': 'MEMBER',
              },
            ),
          );
        },
      ),
    );

    await ApiSettingsRepository(client).createInvite(UserRole.member);

    expect(requestBody, <String, dynamic>{'targetRole': 'MEMBER'});
  });
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clearToken() async {}

  @override
  Future<String?> readToken() async => 'test-token';

  @override
  Future<void> writeToken(String token, {bool persist = true}) async {}
}
