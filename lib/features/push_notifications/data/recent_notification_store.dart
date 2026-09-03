import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class RecentNotificationStore {
  Future<bool> claim({
    required String notificationKey,
    required String occurrenceKey,
  });
}

class SharedPreferencesRecentNotificationStore
    implements RecentNotificationStore {
  static const _notificationKeysStorageKey = 'recent_notification_keys';
  static const _occurrenceKeysStorageKey = 'recent_boss_notification_events';
  static const _maximumEntries = 100;

  Future<void> _operation = Future<void>.value();

  @override
  Future<bool> claim({
    required String notificationKey,
    required String occurrenceKey,
  }) {
    late bool isNew;
    _operation = _operation.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final notificationKeys =
          preferences.getStringList(_notificationKeysStorageKey) ?? <String>[];
      final occurrenceKeys =
          preferences.getStringList(_occurrenceKeysStorageKey) ?? <String>[];
      isNew =
          !notificationKeys.contains(notificationKey) &&
          !occurrenceKeys.contains(occurrenceKey);

      _appendUnique(notificationKeys, notificationKey);
      _appendUnique(occurrenceKeys, occurrenceKey);
      await Future.wait<bool>(<Future<bool>>[
        preferences.setStringList(
          _notificationKeysStorageKey,
          notificationKeys,
        ),
        preferences.setStringList(_occurrenceKeysStorageKey, occurrenceKeys),
      ]);
    });
    return _operation.then((_) => isNew);
  }

  static void _appendUnique(List<String> values, String value) {
    values.remove(value);
    values.add(value);
    if (values.length > _maximumEntries) {
      values.removeRange(0, values.length - _maximumEntries);
    }
  }
}

final recentNotificationStoreProvider = Provider<RecentNotificationStore>(
  (ref) => SharedPreferencesRecentNotificationStore(),
);
