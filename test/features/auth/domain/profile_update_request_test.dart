import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/profile_update_request.dart';

void main() {
  test('원본 내 정보 설정의 전체 항목을 API 요청 형식으로 변환한다', () {
    const request = ProfileUpdateRequest(
      nickname: '프레이야',
      occupation: '소서리스',
      mainClass: '아크 메이지',
      combatPower: 123456,
      equipment: <String, dynamic>{
        '무기': <String, String>{'val': '발뭉 7강', 'color': 'legend'},
      },
      skills: <String, dynamic>{
        'active': <String, String>{'영웅 1': '5강'},
        'passive': <String, String>{'전설 1': '1강'},
      },
      maxCritRate: 52.3,
      maxCritResist: 41.2,
      statusEffectAccuracy: 18.5,
      alternateCharacters: <AlternateCharacter>[
        AlternateCharacter(characterName: '프레이야2', mainClass: '바드'),
      ],
      password: 'new-password',
    );

    expect(request.toJson(), <String, dynamic>{
      'nickname': '프레이야',
      'occupation': '소서리스',
      'main_class': '아크 메이지',
      'combat_power': 123456,
      'equipment': <String, dynamic>{
        '무기': <String, String>{'val': '발뭉 7강', 'color': 'legend'},
      },
      'skills': <String, dynamic>{
        'active': <String, String>{'영웅 1': '5강'},
        'passive': <String, String>{'전설 1': '1강'},
      },
      'max_crit_rate': 52.3,
      'max_crit_resist': 41.2,
      'status_effect_acc': 18.5,
      'alternate_characters': <Map<String, dynamic>>[
        <String, dynamic>{'character_name': '프레이야2', 'main_class': '바드'},
      ],
      'password': 'new-password',
    });
  });

  test('비밀번호를 비우면 기존 비밀번호를 유지하도록 요청에서 제외한다', () {
    const request = ProfileUpdateRequest(
      nickname: '토르',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 0,
      equipment: <String, dynamic>{},
      skills: <String, dynamic>{},
      maxCritRate: 0,
      maxCritResist: 0,
      statusEffectAccuracy: 0,
      alternateCharacters: <AlternateCharacter>[],
      password: '',
    );

    expect(request.toJson(), isNot(contains('password')));
  });
}
