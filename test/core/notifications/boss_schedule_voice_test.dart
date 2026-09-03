import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/notifications/boss_schedule_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('리드타임별 보스 음성 문구를 만든다', () {
    expect(
      bossScheduleVoiceMessage(bossType: '본섭', boss: '파르바', leadSeconds: 300),
      '본섭 파르바 5분 전입니다.',
    );
    expect(
      bossScheduleVoiceMessage(bossType: '고정', boss: '베르드', leadSeconds: 0),
      '고정 베르드 타임입니다.',
    );
  });

  test('음성 설정 기본값은 켜짐이고 저장된 끄기를 존중한다', () async {
    expect(await isBossScheduleVoiceEnabled(), isTrue);

    SharedPreferences.setMockInitialValues(<String, Object>{
      bossScheduleVoiceEnabledStorageKey: false,
    });
    expect(await isBossScheduleVoiceEnabled(), isFalse);
  });
}
