import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/push_notifications/data/recent_notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('동일 notificationKey는 한 번만 표시 대상으로 claim한다', () async {
    final store = SharedPreferencesRecentNotificationStore();

    expect(
      await store.claim(
        notificationKey: 'boss:1:7:1000:300',
        occurrenceKey: '7:1000:300',
      ),
      isTrue,
    );
    expect(
      await store.claim(
        notificationKey: 'boss:1:7:1000:300',
        occurrenceKey: '7:1000:300',
      ),
      isFalse,
    );
  });

  test('로컬 키와 FCM 키가 달라도 occurrence가 같으면 중복 표시하지 않는다', () async {
    final store = SharedPreferencesRecentNotificationStore();

    await store.claim(
      notificationKey: 'boss:local:7:1000:60',
      occurrenceKey: '7:1000:60',
    );
    final shouldDisplayFcm = await store.claim(
      notificationKey: 'boss:1:7:1000:60',
      occurrenceKey: '7:1000:60',
    );

    expect(shouldDisplayFcm, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('recent_notification_keys'),
      containsAll(<String>['boss:local:7:1000:60', 'boss:1:7:1000:60']),
    );
  });
}
