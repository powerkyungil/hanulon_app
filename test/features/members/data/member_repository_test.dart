import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_client.dart';
import 'package:odin_guild_app/core/storage/token_storage.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/members/data/member_repository.dart';

void main() {
  test('정식 members API의 envelope와 camelCase 프로필을 구조화한다', () async {
    late RequestOptions request;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 7,
                    'role': 'MASTER',
                    'nickname': '프레이야',
                    'occupation': '소서리스',
                    'mainClass': '아크 메이지',
                    'combatPower': 142530,
                    'maxCritRate': 52.3,
                    'maxCritResist': '41.2',
                    'statusEffectAcc': 18,
                    'equipment': <String, dynamic>{
                      '무기': <String, String>{'val': '발뭉 7강', 'color': 'legend'},
                    },
                    'skills': <String, dynamic>{
                      'active': <String, String>{'영웅 1': '8강'},
                      'passive': <String, String>{'전설 1': '1강'},
                    },
                    'alternateCharacters': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 1,
                        'characterName': '프레이야2',
                        'mainClass': '바드',
                      },
                    ],
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final members = await ApiMemberRepository(client).fetchMembers();
    final member = members.single;

    expect(request.method, 'GET');
    expect(request.path, '/api/v1/members');
    expect(member.mainClass, '아크 메이지');
    expect(member.combatPower, 142530);
    expect(member.equipment['무기']?.value, '발뭉 7강');
    expect(member.alternateCharacter?.mainClass, '바드');
  });

  test('원본 users API의 JSON 문자열 장비와 스킬을 구조화한다', () async {
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
              data: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 7,
                  'role': 'MASTER',
                  'nickname': '프레이야',
                  'occupation': '소서리스',
                  'main_class': '아크 메이지',
                  'combat_power': 142530,
                  'max_crit_rate': 52.3,
                  'max_crit_resist': '41.2',
                  'status_effect_acc': 18,
                  'equipment': '{"무기":{"val":"발뭉 7강","color":"legend"}}',
                  'skills': '{"active":{"영웅 1":"8강"},"passive":{"전설 1":"1강"}}',
                  'alternate_characters': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 1,
                      'character_name': '프레이야2',
                      'main_class': '바드',
                    },
                  ],
                },
              ],
            ),
          );
        },
      ),
    );

    final members = await ApiMemberRepository(client).fetchMembers();
    final member = members.single;

    expect(member.equipment['무기']?.value, '발뭉 7강');
    expect(member.equipment['무기']?.grade, 'legend');
    expect(member.activeSkills['영웅 1'], '8강');
    expect(member.activeSkills['영웅 2'], 'X');
    expect(member.passiveSkills['전설 1'], '1강');
    expect(member.maxCritResist, 41.2);
    expect(member.alternateCharacter?.characterName, '프레이야2');
  });

  test('회원 관리 요청은 V1 경로와 camelCase payload를 사용한다', () async {
    final requests = <RequestOptions>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _FakeTokenStorage(),
    );
    client.raw.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Object?>(requestOptions: options, statusCode: 204),
          );
        },
      ),
    );
    final repository = ApiMemberRepository(client);

    await repository.changeRole(8, UserRole.admin);
    await repository.transferGuildMaster(8);
    await repository.resetPassword(8);
    await repository.removeMember(8);

    expect(requests[0].method, 'PUT');
    expect(requests[0].path, '/api/v1/members/8/role');
    expect(requests[0].data, <String, String>{'role': 'ADMIN'});
    expect(requests[1].method, 'PUT');
    expect(requests[1].path, '/api/v1/guild/master');
    expect(requests[1].data, <String, int>{'targetUserId': 8});
    expect(requests[2].method, 'PUT');
    expect(requests[2].path, '/api/v1/members/8/password-reset');
    expect(requests[3].method, 'DELETE');
    expect(requests[3].path, '/api/v1/members/8');
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
