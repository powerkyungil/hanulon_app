import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/push_notifications/data/push_token_repository.dart';

void main() {
  test('Android FCM 토큰과 설치 UUID를 PUT 계약으로 등록한다', () async {
    late RequestOptions request;
    final repository = ApiPushTokenRepository(
      _client((options, handler) {
        request = options;
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{
              'data': <String, dynamic>{
                'id': 12,
                'platform': 'ANDROID',
                'deviceId': 'installation-id',
                'updatedAt': 1787461200000,
              },
            },
          ),
        );
      }),
    );

    await repository.register(
      token: 'fcm-registration-token',
      deviceId: 'installation-id',
    );

    expect(request.method, 'PUT');
    expect(request.path, '/api/v1/push-tokens');
    expect(request.data, <String, String>{
      'token': 'fcm-registration-token',
      'platform': 'ANDROID',
      'deviceId': 'installation-id',
    });
  });

  test('로그아웃 토큰 삭제는 body를 포함한 DELETE 계약을 사용한다', () async {
    late RequestOptions request;
    final repository = ApiPushTokenRepository(
      _client((options, handler) {
        request = options;
        handler.resolve(
          Response<Object?>(requestOptions: options, statusCode: 204),
        );
      }),
    );

    await repository.delete(token: 'fcm-registration-token');

    expect(request.method, 'DELETE');
    expect(request.path, '/api/v1/push-tokens');
    expect(request.data, <String, String>{'token': 'fcm-registration-token'});
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
