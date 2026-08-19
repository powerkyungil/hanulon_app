import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/data/auth_repository.dart';
import 'package:odin_guild_app/features/auth/domain/registration_mode.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';

void main() {
  test('로그인 API의 v1 요청과 응답 형식을 연결한다', () async {
    late RequestOptions request;
    final client = _client((options, handler) {
      request = options;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'token': 'jwt-token',
            'userId': 7,
            'username': 'freya',
            'nickname': '프레이야',
            'role': 'MASTER',
          },
        ),
      );
    });

    final session = await ApiAuthRepository(
      client,
    ).login(username: 'freya', password: 'password');

    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/login');
    expect(request.data, <String, String>{
      'username': 'freya',
      'password': 'password',
    });
    expect(session.accessToken, 'jwt-token');
    expect(session.userId, 7);
    expect(session.nickname, '프레이야');
    expect(session.role, UserRole.master);
  });

  test('로그인 API의 v1 data envelope도 세션으로 변환한다', () async {
    final client = _client((options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'token': 'v1-jwt-token',
              'userId': 8,
              'username': 'thor',
              'nickname': '토르',
              'role': 'MEMBER',
            },
          },
        ),
      );
    });

    final session = await ApiAuthRepository(
      client,
    ).login(username: 'thor', password: 'password');

    expect(session.accessToken, 'v1-jwt-token');
    expect(session.userId, 8);
    expect(session.role, UserRole.member);
  });

  test('회원가입 API에 기존 길드 가입 payload를 그대로 전송한다', () async {
    late RequestOptions request;
    final client = _client((options, handler) {
      request = options;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 201,
          data: <String, dynamic>{'userId': 9, 'guildId': 3, 'role': 'MEMBER'},
        ),
      );
    });
    const registration = RegistrationRequest(
      mode: RegistrationMode.joinGuild,
      inviteCode: 'odin-7k4p',
      username: 'thor',
      password: 'password',
      nickname: '토르',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 130000,
      equipment: <String, dynamic>{
        '무기': <String, String>{'val': '발뭉 7강', 'color': 'legend'},
      },
      skills: <String, dynamic>{
        'active': <String, String>{'영웅 1': '8강'},
        'passive': <String, String>{'전설 1': 'X'},
      },
    );

    await ApiAuthRepository(client).register(registration);

    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/register');
    expect(request.data, registration.toJson());
  });

  test('새 길드 생성 API에는 생성 모드와 길드명만 전송한다', () async {
    late RequestOptions request;
    final client = _client((options, handler) {
      request = options;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 201,
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'userId': 10,
              'guildId': 4,
              'role': 'MASTER',
            },
          },
        ),
      );
    });
    const registration = RegistrationRequest(
      mode: RegistrationMode.createGuild,
      inviteCode: 'previous-invite-code',
      guildName: '새 길드',
      username: 'guildmaster',
      password: 'password',
      nickname: '길드장',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 130000,
      equipment: <String, dynamic>{},
      skills: <String, dynamic>{},
    );

    await ApiAuthRepository(client).register(registration);

    expect(request.path, '/api/v1/auth/register');
    expect(request.data, containsPair('mode', 'CREATE_GUILD'));
    expect(request.data, containsPair('guild_name', '새 길드'));
    expect((request.data as Map<String, dynamic>).containsKey('code'), isFalse);
  });

  test('v1 길드 설정 envelope에서 전투력 수정 정책을 읽는다', () async {
    final client = _client((options, handler) {
      expect(options.method, 'GET');
      expect(options.path, '/api/v1/guild/settings');
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'guildName': '오딘 길드',
              'allowMemberCombatPowerEdit': false,
            },
          },
        ),
      );
    });

    final settings = await ApiAuthRepository(client).fetchProfileSettings();

    expect(settings.allowCombatPowerEdit, isFalse);
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
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token, {bool persist = true}) async {}
}
