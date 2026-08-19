import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/notice/data/notice_repository.dart';
import 'package:odin_guild_app/features/notice/domain/notice_article.dart';

void main() {
  test('v1 공지 API의 길드룰·가격표·보스 통제를 함께 조회한다', () async {
    final client = _client((options, handler) {
      final data = switch (options.path) {
        '/api/v1/notices/rules' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'title': '길드 운영 내규',
              'content': '길드 내규 > 참여 > 미리 알려 주세요.',
              'color': '#F2B705',
              'sortOrder': 2,
              'updatedAt': DateTime.utc(2026, 8, 11, 1).millisecondsSinceEpoch,
            },
          ],
        },
        '/api/v1/notices/price-guides' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 2,
              'title': '전설 아이템',
              'content': '방어구 > 발키리 갑옷 > 15000',
              'color': '#fbbf24',
              'sortOrder': 0,
              'updatedAt': DateTime.utc(2026, 8, 11, 2).millisecondsSinceEpoch,
            },
          ],
        },
        '/api/v1/notices/boss-controls' => <String, dynamic>{
          'data': <String, dynamic>{
            'chapters': <Map<String, dynamic>>[
              <String, dynamic>{
                'chapter': '요툰하임',
                'bosses': <Map<String, String>>[
                  <String, String>{'name': '파르바', 'status': 'CONTROL'},
                ],
              },
            ],
          },
        },
        _ => null,
      };
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 200, data: data),
      );
    });

    final overview = await ApiNoticeRepository(client).fetchOverview();

    expect(overview.rules.single.sortOrder, 2);
    expect(overview.rules.single.updatedAt, DateTime.utc(2026, 8, 11, 1));
    expect(overview.priceGuides.single.title, '전설 아이템');
    expect(overview.bossControls.single.bosses.single.status, 'CONTROL');
  });

  test('공지 관리 요청을 v1 API 형식으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'id': 7,
              'title': '운영 내규',
              'content': '길드 내규 > 참여 > 사전 표시',
              'color': '#F2B705',
              'sortOrder': 0,
              'updatedAt': 0,
            },
          },
        ),
      );
    });
    final repository = ApiNoticeRepository(client);
    const input = NoticeArticleInput(
      title: '운영 내규',
      content: '길드 내규 > 참여 > 사전 표시',
      color: '#F2B705',
    );

    await repository.createArticle(NoticeArticleType.rule, input);
    await repository.updateArticle(NoticeArticleType.priceGuide, 7, input);
    await repository.reorderRules(<int>[3, 1, 2]);
    await repository.updateBossControl(
      chapter: '요툰하임',
      boss: '파르바',
      status: 'ALLY_ONLY',
    );
    await repository.deleteArticle(NoticeArticleType.rule, 4);

    expect(requests[0].method, 'POST');
    expect(requests[0].path, '/api/v1/notices/rules');
    expect((requests[0].data as Map)['title'], '운영 내규');
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/notices/price-guides/7');
    expect(requests[2].path, '/api/v1/notices/rules/order');
    expect((requests[2].data as Map)['ids'], <int>[3, 1, 2]);
    expect(requests[3].path, '/api/v1/notices/boss-controls');
    expect((requests[3].data as Map)['status'], 'ALLY_ONLY');
    expect(requests[4].method, 'DELETE');
    expect(requests[4].path, '/api/v1/notices/rules/4');
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
