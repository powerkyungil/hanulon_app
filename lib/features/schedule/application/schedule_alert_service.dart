import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/theme/app_colors.dart';

const _androidNotificationIcon = 'ic_notification';

class ScheduleAlertService {
  ScheduleAlertService(this._tts, this._notifications);

  final FlutterTts _tts;
  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings(_androidNotificationIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _notifications.initialize(initializationSettings);

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Notification support and permissions differ by platform. A failed
      // app notification must never interrupt schedule polling or TTS.
    }
  }

  Future<void> showPushAlert({
    required String notificationKey,
    required String message,
  }) async {
    try {
      await initialize();
      await _notifications.show(
        _notificationId(notificationKey),
        '보스 스케줄',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'boss_schedule_alerts',
            '보스 일정 알림',
            channelDescription: '보스 출현 전 알림',
            importance: Importance.max,
            priority: Priority.high,
            icon: _androidNotificationIcon,
            color: AppColors.iconPurplePrimary,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: notificationKey,
      );
    } catch (_) {
      // Notification support and permissions differ by platform. A failed
      // app notification must never interrupt schedule polling or TTS.
    }
  }

  int _notificationId(String key) {
    var hash = 2166136261;
    for (final codeUnit in key.codeUnits) {
      hash = (hash ^ codeUnit) * 16777619 & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<void> speak(String message) async {
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1);
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {
      // TTS availability differs by platform. A failed voice alert must never
      // interrupt schedule polling or the rest of the screen.
    }
  }
}

final scheduleAlertServiceProvider = Provider<ScheduleAlertService>((ref) {
  return ScheduleAlertService(FlutterTts(), FlutterLocalNotificationsPlugin());
});
