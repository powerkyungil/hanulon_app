import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/auth/domain/registration_mode.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';

void main() {
  test('회원가입 요청은 가입 코드를 전송한다', () {
    const request = RegistrationRequest(
      mode: RegistrationMode.joinGuild,
      inviteCode: 'ODIN-7K4P',
      username: 'new-member',
      password: 'secret-password',
      nickname: '새 길드원',
      occupation: '전사',
      mainClass: '워리어',
      combatPower: 123456,
      equipment: <String, dynamic>{},
      skills: <String, dynamic>{},
    );

    final json = request.toJson();

    expect(json['code'], 'ODIN-7K4P');
    expect(json.containsKey('token'), isFalse);
  });

  test('새 길드 생성 요청은 코드 없이 길드명과 생성 모드를 전송한다', () {
    const request = RegistrationRequest(
      mode: RegistrationMode.createGuild,
      guildName: '새 오딘 길드',
      username: 'guild-master',
      password: 'secret-password',
      nickname: '길드장',
      occupation: '전사',
      mainClass: '워리어',
      combatPower: 123456,
      equipment: <String, dynamic>{},
      skills: <String, dynamic>{},
    );

    final json = request.toJson();

    expect(json['mode'], 'CREATE_GUILD');
    expect(json['guild_name'], '새 오딘 길드');
    expect(json.containsKey('code'), isFalse);
  });
}
