import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/content_groups/data/content_group_repository.dart';

void main() {
  test('V1 그룹 API의 봉투 응답과 길드원 ID 목록을 변환한다', () async {
    final client = _client((options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'name': '1군 레이드',
                'memberIds': <dynamic>[7, '8'],
              },
              <String, dynamic>{
                'id': 2,
                'name': '2군 레이드',
                'memberIds': <int>[9, 10],
              },
            ],
          },
        ),
      );
    });

    final groups = await ApiContentGroupRepository(client).fetchGroups();

    expect(groups.first.name, '1군 레이드');
    expect(groups.first.memberIds, <int>[7, 8]);
    expect(groups.last.memberIds, <int>[9, 10]);
  });

  test('그룹 관리 요청을 V1 API 형식으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: options.method == 'POST' ? 201 : 204,
          data: options.method == 'POST'
              ? <String, dynamic>{
                  'data': <String, dynamic>{
                    'id': 3,
                    'name': '발할라',
                    'memberIds': <int>[],
                  },
                }
              : null,
        ),
      );
    });
    final repository = ApiContentGroupRepository(client);

    final created = await repository.createGroup('발할라');
    await repository.renameGroup(3, '발할라 1군');
    await repository.saveMembers(3, <int>[7, 8, 9]);
    await repository.deleteGroup(3);

    expect(created.id, 3);
    expect(requests[0].path, '/api/v1/content-groups');
    expect((requests[0].data as Map)['name'], '발할라');
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/content-groups/3');
    expect(requests[2].method, 'PUT');
    expect(requests[2].path, '/api/v1/content-groups/3/members');
    expect((requests[2].data as Map)['userIds'], <int>[7, 8, 9]);
    expect(requests[3].method, 'DELETE');
    expect(requests[3].path, '/api/v1/content-groups/3');
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
