import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/boss_vote/data/boss_vote_repository.dart';
import 'package:odin_guild_app/features/boss_vote/domain/manual_vote_input.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_boss.dart';
import 'package:odin_guild_app/features/boss_vote/domain/vote_participant.dart';

void main() {
  test('V1 투표 목록 envelope를 도메인 모델로 변환한다', () async {
    final client = _client((options, handler) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'voteKey': '본섭|요툰하임|파르바|1786406400000',
                'type': '본섭',
                'region': '요툰하임',
                'boss': '파르바',
                'spawnTime': 1786406400000,
                'participants': <Map<String, dynamic>>[
                  <String, dynamic>{'userId': 3, 'nickname': '프레이야'},
                ],
                'joined': true,
                'isClosed': false,
                'isBlessed': true,
                'isManual': false,
                'isHistory': false,
              },
            ],
          },
        ),
      );
    });

    final votes = await ApiBossVoteRepository(client).fetchVoteBosses();

    expect(votes.single.voteKey, '본섭|요툰하임|파르바|1786406400000');
    expect(votes.single.participants.single.userId, 3);
    expect(votes.single.participants.single.nickname, '프레이야');
    expect(votes.single.joined, isTrue);
    expect(votes.single.isBlessed, isTrue);
  });

  test('V1 수동 투표 생성과 참여 토글 요청을 전용 계약으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      final data = options.path == '/api/v1/boss-votes/manual'
          ? <String, dynamic>{
              'data': <String, dynamic>{'id': 9, 'voteKey': 'manual|9'},
            }
          : <String, dynamic>{
              'data': <String, dynamic>{'joined': true},
            };
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: options.path.endsWith('/manual') ? 201 : 200,
          data: data,
        ),
      );
    });

    const input = ManualVoteInput(
      boss: '  파르바 ',
      spawnTime: 1786406400000,
      type: '공통',
      region: ' 요툰하임 ',
      isBlessed: true,
    );
    final repository = ApiBossVoteRepository(client);
    await repository.createManualVote(input);
    final joined = await repository.toggleParticipation(
      const VoteBoss(
        id: 9,
        voteKey: 'manual|9',
        type: '공통',
        region: '요툰하임',
        boss: '파르바',
        spawnTime: 1786406400000,
        participants: <VoteParticipant>[],
        joined: false,
        isClosed: false,
        isBlessed: true,
        isManual: true,
        isHistory: false,
      ),
    );

    expect(requests[0].method, 'POST');
    expect(requests[0].path, '/api/v1/boss-votes/manual');
    expect(requests[0].data, <String, dynamic>{
      'boss': '파르바',
      'spawnTime': 1786406400000,
      'type': '공통',
      'region': '요툰하임',
      'isBlessed': true,
    });
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/boss-votes/manual%7C9/participation');
    expect(requests[1].data, <String, dynamic>{
      'boss': '파르바',
      'spawnTime': 1786406400000,
    });
    expect(joined, isTrue);
  });

  test('선택 캐릭터 조회와 대리 행위자 정보를 투표 모델에 보존한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      final response = options.method == 'GET'
          ? <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 9,
                  'voteKey': '본섭|요툰하임|파르바|1786406400000',
                  'type': '본섭',
                  'region': '요툰하임',
                  'boss': '파르바',
                  'spawnTime': 1786406400000,
                  'participants': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'userId': 123,
                      'nickname': '프레이야',
                      'characterType': 'ALTERNATE',
                      'characterKey': 'ALTERNATE:123',
                      'characterName': '프레이야 부캐',
                      'votedBy': <String, dynamic>{
                        'accountType': 'DEPUTY',
                        'accountId': null,
                        'nickname': '공용 부주',
                      },
                    },
                  ],
                  'joined': true,
                  'isClosed': false,
                  'isBlessed': false,
                  'isManual': false,
                  'isHistory': false,
                },
              ],
            }
          : <String, dynamic>{
              'data': <String, dynamic>{'joined': false},
            };
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: response,
        ),
      );
    });

    final repository = ApiBossVoteRepository(client);
    final vote = (await repository.fetchVoteBossesForCharacter(
      characterKey: 'ALTERNATE:123',
    )).single;
    final joined = await repository.toggleParticipationForCharacter(
      vote,
      characterKey: 'ALTERNATE:123',
    );

    final participant = vote.participants.single;
    expect(requests[0].queryParameters, <String, dynamic>{
      'characterKey': 'ALTERNATE:123',
    });
    expect(participant.characterKey, 'ALTERNATE:123');
    expect(participant.targetDisplayName, '프레이야 부캐');
    expect(participant.votedBy?.accountType, 'DEPUTY');
    expect(participant.votedBy?.accountId, isNull);
    expect(participant.votedBy?.nickname, '공용 부주');
    expect(requests[1].data, <String, dynamic>{
      'boss': '파르바',
      'spawnTime': 1786406400000,
      'characterKey': 'ALTERNATE:123',
    });
    expect(joined, isFalse);
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
