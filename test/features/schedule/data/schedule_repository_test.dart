import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/core/time/server_clock.dart';
import 'package:odin_guild_app/features/schedule/data/schedule_repository.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_definition.dart';
import 'package:odin_guild_app/features/schedule/domain/boss_schedule.dart';

void main() {
  test('V1 일정·보스·참여 상태 봉투 응답을 하나의 현황으로 통합한다', () async {
    const spawnTime = 1_786_406_400_000;
    final client = _client((options, handler) {
      final data = switch (options.path) {
        '/api/v1/schedules' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'bossDefinitionId': 3,
              'type': '본섭',
              'region': '요툰하임',
              'boss': '파르바',
              'spawnTime': spawnTime,
              'isMung': false,
              'isFixed': false,
            },
          ],
        },
        '/api/v1/participation-targets' => <String, dynamic>{
          'data': <String, dynamic>{
            'bossDefinitionIds': <int>[3],
          },
        },
        '/api/v1/participants' => <String, dynamic>{
          'data': <String, dynamic>{
            '본섭|요툰하임|파르바|$spawnTime': <String>['프레이야'],
          },
        },
        '/api/v1/participation-states' => <String, dynamic>{
          'data': <String>['본섭|요툰하임|파르바|$spawnTime'],
        },
        '/api/v1/time' => <String, dynamic>{
          'data': <String, dynamic>{
            'epochMs': spawnTime - 60_000,
            'timeZone': 'Asia/Seoul',
          },
        },
        '/api/v1/bosses' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 3,
              'type': '본섭',
              'region': '요툰하임',
              'boss': '파르바',
              'cooldownHours': 12,
              'timeText': null,
              'days': <String>[],
              'color': null,
              'sortOrder': 0,
            },
          ],
        },
        _ => throw StateError('예상하지 못한 경로: ${options.path}'),
      };
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 200, data: data),
      );
    });

    final overview = await ApiScheduleRepository(
      client,
      ServerClock(),
    ).fetchOverview();

    expect(overview.schedules.single.boss, '파르바');
    expect(overview.schedules.single.bossDefinitionId, 3);
    expect(overview.schedules.single.isMung, isFalse);
    expect(overview.participationTargetBossDefinitionIds, <int>{3});
    expect(overview.participantsFor(overview.schedules.single), <String>[
      '프레이야',
    ]);
    expect(overview.closedVoteKeys, <String>{'본섭|요툰하임|파르바|$spawnTime'});
  });

  test('기존 보스명 기반 참여 설정과 ID 없는 일정을 호환한다', () async {
    const spawnTime = 1_786_406_400_000;
    final client = _client((options, handler) {
      final data = switch (options.path) {
        '/api/v1/schedules' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'type': '본섭',
              'region': '요툰하임',
              'boss': '파르바',
              'spawnTime': spawnTime,
              'isMung': false,
            },
          ],
        },
        '/api/v1/participation-targets' => <String, dynamic>{
          'data': <String>['파르바'],
        },
        '/api/v1/participants' => <String, dynamic>{
          'data': <String, dynamic>{},
        },
        '/api/v1/participation-states' => <String, dynamic>{'data': <String>[]},
        '/api/v1/time' => <String, dynamic>{
          'data': <String, dynamic>{'epochMs': spawnTime},
        },
        '/api/v1/bosses' => <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 3,
              'type': '본섭',
              'region': '요툰하임',
              'boss': '파르바',
              'cooldownHours': 12,
            },
          ],
        },
        _ => throw StateError('예상하지 못한 경로: ${options.path}'),
      };
      handler.resolve(
        Response<Object?>(requestOptions: options, statusCode: 200, data: data),
      );
    });

    final overview = await ApiScheduleRepository(
      client,
      ServerClock(),
    ).fetchOverview();

    expect(overview.schedules.single.bossDefinitionId, 3);
    expect(overview.participationTargetBossDefinitionIds, <int>{3});
    expect(overview.canParticipate(overview.schedules.single), isTrue);
  });

  test('일정·보스·참여 관리 요청을 V1 API 형식으로 전달한다', () async {
    final requests = <RequestOptions>[];
    final client = _client((options, handler) {
      requests.add(options);
      final data = options.path.startsWith('/api/v1/participants/')
          ? <String, dynamic>{
              'data': <String, bool>{'joined': true},
            }
          : null;
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode:
              options.method == 'POST' &&
                  (options.path == '/api/v1/schedules' ||
                      options.path == '/api/v1/bosses')
              ? 201
              : options.path.startsWith('/api/v1/participants/') ||
                    options.path.endsWith('/cut') ||
                    options.path.endsWith('/mung')
              ? 200
              : 204,
          data: data,
        ),
      );
    });
    final repository = ApiScheduleRepository(client, ServerClock());
    const schedule = BossSchedule(
      id: 7,
      bossDefinitionId: 3,
      type: '본섭',
      region: '요툰하임',
      boss: '파르바',
      spawnTime: 1_786_406_400_000,
      isMung: false,
    );
    const definition = BossDefinition(
      id: 3,
      type: '본섭',
      region: '요툰하임',
      boss: '파르바',
      cooldownHours: 12,
      timeText: null,
      days: <String>[],
      color: null,
      sortOrder: 0,
    );

    await repository.createSchedules(<BossSchedule>[schedule]);
    await repository.saveParticipationTargets(<int>{3, 9});
    await repository.createBoss(definition);
    await repository.deleteBoss(3);
    await repository.reorderBosses(<BossDefinition>[definition]);
    await repository.resetBosses();
    await repository.cut(schedule);
    await repository.mung(schedule);
    await repository.deleteSchedule(7);
    await repository.deleteAll();
    final joined = await repository.toggleParticipation(schedule);

    expect(requests[0].method, 'POST');
    expect(requests[0].path, '/api/v1/schedules');
    expect((requests[0].data as Map)['schedules'], hasLength(1));
    expect(
      ((requests[0].data as Map)['schedules'] as List)
          .single['bossDefinitionId'],
      3,
    );
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/participation-targets');
    expect((requests[1].data as Map)['bossDefinitionIds'], <int>[3, 9]);
    expect(requests[2].path, '/api/v1/bosses');
    expect((requests[2].data as Map)['cooldownHours'], 12);
    expect((requests[2].data as Map)['days'], isEmpty);
    expect(requests[3].method, 'DELETE');
    expect(requests[3].path, '/api/v1/bosses/3');
    expect(requests[4].method, 'PUT');
    expect(requests[4].path, '/api/v1/bosses/order');
    expect((requests[4].data as Map)['bossIds'], <int>[3]);
    expect(requests[5].path, '/api/v1/bosses/reset');
    expect(requests[6].path, '/api/v1/schedules/cut');
    expect(requests[7].path, '/api/v1/schedules/mung');
    expect(requests[8].path, '/api/v1/schedules/7');
    expect(requests[9].path, '/api/v1/schedules');
    expect(requests[10].method, 'PUT');
    expect(
      requests[10].path,
      '/api/v1/participants/${Uri.encodeComponent('파르바')}',
    );
    expect(joined, isTrue);
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
