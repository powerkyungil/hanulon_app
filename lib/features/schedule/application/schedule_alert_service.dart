import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/notifications/boss_schedule_voice.dart';
import '../../push_notifications/application/push_notification_service.dart';
import '../../push_notifications/data/recent_notification_store.dart';
import '../../push_notifications/domain/boss_push_payload.dart';

class ScheduleAlertService {
  ScheduleAlertService(
    this._tts,
    this._notifications,
    this._recentNotificationStore,
  );

  final FlutterTts _tts;
  final FlutterLocalNotificationsPlugin _notifications;
  final RecentNotificationStore _recentNotificationStore;

  Future<void> initialize() async {}

  Future<void> showPushAlert({
    required int bossDefinitionId,
    required int? scheduleId,
    required String bossType,
    required String region,
    required String boss,
    required int spawnTime,
    required int leadSeconds,
    required String message,
  }) async {
    try {
      final occurrenceKey = '$bossDefinitionId:$spawnTime:$leadSeconds';
      final notificationKey = 'boss:local:$occurrenceKey';
      final isNew = await _recentNotificationStore.claim(
        notificationKey: notificationKey,
        occurrenceKey: occurrenceKey,
      );
      if (!isNew) return;
      final payload = BossPushPayload(
        notificationKey: notificationKey,
        guildId: null,
        scheduleId: scheduleId,
        bossDefinitionId: bossDefinitionId,
        bossType: bossType,
        region: region,
        boss: boss,
        spawnTime: spawnTime,
        leadSeconds: leadSeconds,
      );
      await _notifications.show(
        notificationIdFor(notificationKey),
        '보스 스케줄',
        message,
        bossScheduleNotificationDetails,
        payload: payload.toJsonPayload(),
      );
    } catch (_) {
      // Notification support and permissions differ by platform. A failed
      // app notification must never interrupt schedule polling or TTS.
    }
  }

  Future<void> speak(String message) async {
    try {
      await speakBossScheduleMessage(_tts, message);
    } catch (_) {
      // TTS availability differs by platform. A failed voice alert must never
      // interrupt schedule polling or the rest of the screen.
    }
  }
}

final scheduleAlertServiceProvider = Provider<ScheduleAlertService>((ref) {
  return ScheduleAlertService(
    FlutterTts(),
    ref.watch(localNotificationsPluginProvider),
    ref.watch(recentNotificationStoreProvider),
  );
});
