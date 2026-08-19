import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/siege/data/siege_repository.dart';
import 'package:odin_guild_app/features/siege/domain/siege_record.dart';

void main() {
  test('V1 공성전 봉투 응답을 전투력 순 기록으로 변환한다', () async {
    final client = _client((options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'userId': 8,
                'nickname': '토르',
                'mainClass': '디펜더',
                'combatPower': 130000,
                'currentDiamonds': 50000,
                'remainingDiamonds': 20000,
                'usedDiamonds': 30000,
                'updatedAt': null,
              },
              <String, dynamic>{
                'userId': 7,
                'nickname': '프레이야',
                'mainClass': '아크 메이지',
                'combatPower': 150000,
                'currentDiamonds': 80000,
                'remainingDiamonds': 35000,
                'usedDiamonds': 45000,
                'updatedAt': 1_786_416_600_000,
              },
            ],
          },
        ),
      );
    });

    final records = await ApiSiegeRepository(client).fetchRecords();

    expect(records.first.nickname, '프레이야');
    expect(records.first.usedDiamonds, 45000);
    expect(records.first.updatedAt, isNotNull);
    expect(records.last.hasEntry, isFalse);
  });

  test('본인·운영진 수정과 전체 초기화를 V1 API 형식으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 204, data: null),
      );
    });
    final repository = ApiSiegeRepository(client);
    const input = SiegeInput(startDiamonds: 80000, remainingDiamonds: 35000);

    await repository.saveMine(input);
    await repository.saveMember(9, input);
    await repository.resetAll();

    expect(requests[0].method, 'PUT');
    expect(requests[0].path, '/api/v1/siege/me');
    expect((requests[0].data as Map)['currentDiamonds'], 80000);
    expect((requests[0].data as Map)['remainingDiamonds'], 35000);
    expect(requests[1].path, '/api/v1/siege/members/9');
    expect(requests[2].method, 'DELETE');
    expect(requests[2].path, '/api/v1/siege');
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
