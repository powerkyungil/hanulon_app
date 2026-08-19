import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/collections/data/collection_repository.dart';
import 'package:odin_guild_app/features/collections/domain/item_collection.dart';

void main() {
  test('V1 컬렉션·길드원·체크·제외 상태를 통합한다', () async {
    final client = _client((options, handler) {
      final data = switch (options.path) {
        '/api/v1/collections' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': '전설 방어구',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 10,
                  'part': '발키리 갑옷',
                  'enchantment': '강화 7',
                  'sortOrder': 0,
                },
              ],
            },
          ],
        },
        '/api/v1/members' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 2,
              'nickname': '로키',
              'combatPower': 120000,
              'role': 'MEMBER',
            },
            <String, dynamic>{
              'id': 1,
              'nickname': '프레이야',
              'combatPower': 150000,
              'role': 'MASTER',
            },
          ],
        },
        '/api/v1/collection-completions' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'userId': 1, 'collectionItemId': 10},
          ],
        },
        '/api/v1/collection-exclusions' => <String, dynamic>{
          'data': <int>[2],
        },
        _ => null,
      };
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 200, data: data),
      );
    });

    final overview = await ApiCollectionRepository(client).fetchOverview();

    expect(overview.collections.single.items.single.id, 10);
    expect(overview.members.first.nickname, '프레이야');
    expect(overview.isCompleted(1, 10), isTrue);
    expect(overview.excludedMemberIds, <int>{2});
  });

  test('컬렉션 관리와 달성 상태를 V1 API 형식으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: options.path == '/api/v1/collection-exclusions/toggle'
              ? <String, dynamic>{
                  'data': <String, String>{'status': 'added'},
                }
              : <String, dynamic>{'data': <String, dynamic>{}},
        ),
      );
    });
    final repository = ApiCollectionRepository(client);
    const input = CollectionInput(
      name: '전설 방어구',
      items: <CollectionItemInput>[
        CollectionItemInput(part: '발키리 갑옷', enchantment: '강화 7'),
      ],
    );
    const updateInput = CollectionInput(
      name: '전설 방어구',
      items: <CollectionItemInput>[
        CollectionItemInput(id: 10, part: '발키리 갑옷', enchantment: '강화 7'),
      ],
    );

    await repository.saveCollection(input);
    await repository.saveCollection(updateInput, collectionId: 3);
    await repository.setCompleted(userId: 7, itemId: 10, completed: true);
    final excluded = await repository.toggleExcluded(7);
    await repository.deleteCollection(3);

    expect(requests[0].method, 'POST');
    expect(requests[0].path, '/api/v1/collections');
    expect((requests[0].data as Map)['name'], '전설 방어구');
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/collections/3');
    expect(requests[2].method, 'PUT');
    expect(requests[2].path, '/api/v1/collection-completions');
    expect((requests[2].data as Map)['collectionItemId'], 10);
    expect(requests[3].path, '/api/v1/collection-exclusions/toggle');
    expect(excluded, isTrue);
    expect(requests[4].method, 'DELETE');
    expect(requests[4].path, '/api/v1/collections/3');
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
