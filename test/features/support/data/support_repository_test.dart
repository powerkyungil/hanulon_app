import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/support/data/support_repository.dart';
import 'package:odin_guild_app/features/support/domain/support_request.dart';

void main() {
  test('v1 손지원 API의 envelope와 epoch 시간, 신청자 정보를 변환한다', () async {
    final client = _client((options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'requesterId': 7,
                'requestedTime': '2026-08-12 20:00~21:00',
                'memo': '장비 세팅 도움',
                'status': 'MATCHED',
                'selectedApplicationId': 10,
                'createdAt': DateTime.utc(
                  2026,
                  8,
                  11,
                  9,
                ).millisecondsSinceEpoch,
                'updatedAt': DateTime.utc(
                  2026,
                  8,
                  11,
                  9,
                  30,
                ).millisecondsSinceEpoch,
                'nickname': '프레이야',
                'occupation': '소서리스',
                'mainClass': '아크 메이지',
                'combatPower': 142530,
                'applications': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 10,
                    'requestId': 1,
                    'applicantId': 8,
                    'memo': '가능합니다.',
                    'status': 'SELECTED',
                    'createdAt': DateTime.utc(
                      2026,
                      8,
                      11,
                      9,
                      10,
                    ).millisecondsSinceEpoch,
                    'nickname': '토르',
                    'occupation': '워리어',
                    'mainClass': '디펜더',
                    'combatPower': 137420,
                  },
                ],
              },
            ],
          },
        ),
      );
    });

    final requests = await ApiSupportRepository(client).fetchRequests();

    expect(requests.single.status, SupportRequestStatus.matched);
    expect(requests.single.selectedApplicationId, 10);
    expect(requests.single.applications.single.nickname, '토르');
    expect(requests.single.applications.single.isSelected, isTrue);
    expect(requests.single.combatPower, 142530);
  });

  test('손지원 등록·상태·신청·선택·취소·삭제 요청을 v1 경로로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, Object>{'success': true},
        ),
      );
    });
    final repository = ApiSupportRepository(client);

    await repository.createRequest(
      const SupportRequestInput(requestedTime: '2026-08-12 종일', memo: '세팅 지원'),
    );
    await repository.apply(3);
    await repository.selectApplication(3, 12);
    await repository.updateStatus(3, SupportRequestStatus.done);
    await repository.cancelApplication(3, 12);
    await repository.deleteRequest(3);

    expect(requests[0].path, '/api/v1/support-requests');
    expect(requests[0].data, <String, String>{
      'requestedTime': '2026-08-12 종일',
      'memo': '세팅 지원',
    });
    expect(requests[1].path, '/api/v1/support-requests/3/applications');
    expect(requests[2].path, '/api/v1/support-requests/3/select/12');
    expect(requests[3].path, '/api/v1/support-requests/3/status');
    expect((requests[3].data as Map)['status'], 'DONE');
    expect(requests[4].path, '/api/v1/support-requests/3/applications/12');
    expect(requests[4].method, 'DELETE');
    expect(requests[5].path, '/api/v1/support-requests/3');
    expect(requests[5].method, 'DELETE');
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
