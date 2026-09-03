import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/push_notifications/domain/boss_push_payload.dart';

void main() {
  const data = <String, String>{
    'type': 'BOSS_SCHEDULE',
    'notificationKey': 'boss:1:7:1787461500000:300',
    'guildId': '1',
    'scheduleId': '',
    'bossDefinitionId': '7',
    'bossType': '고정',
    'region': '미드가르드',
    'boss': '파르바',
    'spawnTime': '1787461500000',
    'leadSeconds': '300',
  };

  test('고정 보스 payload는 빈 scheduleId 대신 정의 ID와 출현 시각을 사용한다', () {
    final payload = BossPushPayload.tryParse(data);

    expect(payload, isNotNull);
    expect(payload?.scheduleId, isNull);
    expect(payload?.bossDefinitionId, 7);
    expect(payload?.spawnTime, 1787461500000);
    expect(payload?.occurrenceKey, '7:1787461500000:300');
    expect(
      payload?.scheduleLocation,
      '/schedule?bossDefinitionId=7&spawnTime=1787461500000',
    );
  });

  test('지원하지 않는 leadSeconds 또는 다른 type은 무시한다', () {
    expect(
      BossPushPayload.tryParse(<String, String>{...data, 'leadSeconds': '30'}),
      isNull,
    );
    expect(
      BossPushPayload.tryParse(<String, String>{...data, 'type': 'NOTICE'}),
      isNull,
    );
  });

  test('로컬 알림 payload JSON을 탭 데이터로 복원한다', () {
    final original = BossPushPayload.tryParse(data)!;
    final restored = BossPushPayload.tryParseJson(original.toJsonPayload());

    expect(restored?.notificationKey, original.notificationKey);
    expect(restored?.bossDefinitionId, original.bossDefinitionId);
    expect(restored?.spawnTime, original.spawnTime);
  });
}
