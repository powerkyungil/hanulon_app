import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/notifications/boss_schedule_voice.dart';
import '../data/recent_notification_store.dart';
import '../domain/boss_push_payload.dart';
import 'push_navigation_controller.dart';
import 'push_token_coordinator.dart';

const bossScheduleChannelId = 'boss_schedule_alerts';
const bossScheduleNotificationIcon = 'ic_notification';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final payload = BossPushPayload.tryParse(message.data);
  if (payload == null) return;
  final isNew = await SharedPreferencesRecentNotificationStore().claim(
    notificationKey: payload.notificationKey,
    occurrenceKey: payload.occurrenceKey,
  );
  try {
    if (!isNew || !await isBossScheduleVoiceEnabled()) return;

    final notificationBody = message.notification?.body?.trim();
    final spokenMessage = notificationBody == null || notificationBody.isEmpty
        ? bossScheduleVoiceMessage(
            bossType: payload.bossType,
            boss: payload.boss,
            leadSeconds: payload.leadSeconds,
          )
        : notificationBody;
    await speakBossScheduleMessage(
      FlutterTts(),
      spokenMessage,
      awaitCompletion: true,
    );
  } catch (_) {
    // A background TTS failure must not prevent the system notification from
    // being delivered or cause FCM background work to fail.
  }
}

abstract interface class PushTokenLifecycle {
  Future<void> registerAfterAuthentication();

  Future<void> removeBeforeLogout();
}

class PushNotificationService implements PushTokenLifecycle {
  PushNotificationService({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin notifications,
    required PushTokenCoordinator tokenCoordinator,
    required RecentNotificationStore recentNotificationStore,
    required void Function(BossPushPayload payload) onNotificationTap,
  }) : _messaging = messaging,
       _notifications = notifications,
       _tokenCoordinator = tokenCoordinator,
       _recentNotificationStore = recentNotificationStore,
       _onNotificationTap = onNotificationTap;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _notifications;
  final PushTokenCoordinator _tokenCoordinator;
  final RecentNotificationStore _recentNotificationStore;
  final void Function(BossPushPayload payload) _onNotificationTap;

  Future<void>? _initialization;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  String? _currentToken;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(bossScheduleNotificationIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );

    final androidNotifications = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        bossScheduleChannelId,
        '보스 일정 알림',
        description: '보스 출현 5분 전, 1분 전과 출현 시점 알림',
        importance: Importance.max,
      ),
    );
    await androidNotifications?.requestNotificationsPermission();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_showForegroundMessage(message)),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteNotificationTap,
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      if (_tokenCoordinator.isAuthenticated) {
        unawaited(_registerRefreshedToken(token));
      }
    });

    final localLaunchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    final localLaunchResponse = localLaunchDetails?.notificationResponse;
    if (localLaunchDetails?.didNotificationLaunchApp ?? false) {
      _handleLocalNotificationTap(localLaunchResponse?.payload);
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteNotificationTap(initialMessage);
    }
  }

  @override
  Future<void> registerAfterAuthentication() async {
    try {
      await initialize();
      final token = await _messaging.getToken();
      _currentToken = token;
      final succeeded = await _tokenCoordinator.registerAfterAuthentication(
        token,
      );
      succeeded ? _resetRetry() : _scheduleRetry();
    } catch (_) {
      _scheduleRetry();
    }
  }

  Future<void> _registerRefreshedToken(String token) async {
    final succeeded = await _tokenCoordinator.registerRefreshedToken(token);
    succeeded ? _resetRetry() : _scheduleRetry();
  }

  void _resetRetry() {
    _retryTimer?.cancel();
    _retryAttempt = 0;
  }

  void _scheduleRetry() {
    if (!_tokenCoordinator.isAuthenticated || _retryTimer?.isActive == true) {
      return;
    }
    const delays = <Duration>[
      Duration(seconds: 10),
      Duration(minutes: 1),
      Duration(minutes: 5),
    ];
    final delay = delays[_retryAttempt.clamp(0, delays.length - 1)];
    _retryAttempt++;
    _retryTimer = Timer(delay, () => unawaited(registerAfterAuthentication()));
  }

  @override
  Future<void> removeBeforeLogout() async {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    String? token = _currentToken;
    try {
      token ??= await _messaging.getToken();
    } catch (_) {}
    await _tokenCoordinator.removeBeforeLogout(token);
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final payload = BossPushPayload.tryParse(message.data);
    if (payload == null) return;
    final isNew = await _recentNotificationStore.claim(
      notificationKey: payload.notificationKey,
      occurrenceKey: payload.occurrenceKey,
    );
    if (!isNew) return;

    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    await _notifications.show(
      notificationIdFor(payload.notificationKey),
      title == null || title.isEmpty ? '보스 스케줄' : title,
      body == null || body.isEmpty ? _fallbackBody(payload) : body,
      bossScheduleNotificationDetails,
      payload: payload.toJsonPayload(),
    );
  }

  void _handleRemoteNotificationTap(RemoteMessage message) {
    final payload = BossPushPayload.tryParse(message.data);
    if (payload == null) return;
    unawaited(
      _recentNotificationStore.claim(
        notificationKey: payload.notificationKey,
        occurrenceKey: payload.occurrenceKey,
      ),
    );
    _onNotificationTap(payload);
  }

  void _handleLocalNotificationTap(String? rawPayload) {
    final payload = BossPushPayload.tryParseJson(rawPayload);
    if (payload != null) _onNotificationTap(payload);
  }

  static String _fallbackBody(BossPushPayload payload) {
    if (payload.leadSeconds == 0) return '${payload.boss} 출현 시간입니다.';
    return '${payload.boss} 출현 ${payload.leadSeconds ~/ 60}분 전입니다.';
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}

int notificationIdFor(String key) {
  var hash = 2166136261;
  for (final codeUnit in key.codeUnits) {
    hash = (hash ^ codeUnit) * 16777619 & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

const bossScheduleNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    bossScheduleChannelId,
    '보스 일정 알림',
    channelDescription: '보스 출현 5분 전, 1분 전과 출현 시점 알림',
    importance: Importance.max,
    priority: Priority.high,
    icon: bossScheduleNotificationIcon,
    color: AppColors.iconPurplePrimary,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

final localNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => FlutterLocalNotificationsPlugin(),
    );

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(
    messaging: FirebaseMessaging.instance,
    notifications: ref.watch(localNotificationsPluginProvider),
    tokenCoordinator: ref.watch(pushTokenCoordinatorProvider),
    recentNotificationStore: ref.watch(recentNotificationStoreProvider),
    onNotificationTap: ref
        .read(pushNavigationControllerProvider.notifier)
        .openSchedule,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final pushTokenLifecycleProvider = Provider<PushTokenLifecycle>(
  (ref) => ref.watch(pushNotificationServiceProvider),
);
