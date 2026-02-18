import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FocusService {
  static final FocusService _instance = FocusService._internal();
  factory FocusService() => _instance;
  FocusService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  Future<void> showFocusNotification({
    required int remainingMinutes,
    required int remainingSeconds,
    required bool isBreak,
  }) async {
    await initialize();

    final title = isBreak ? 'Перерыв' : 'Режим фокусировки';
    final body =
        'Осталось: ${remainingMinutes.toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';

    const androidDetails = AndroidNotificationDetails(
      'focus_timer',
      'Таймер фокусировки',
      channelDescription: 'Уведомления таймера фокусировки',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: false,
      playSound: false,
      enableVibration: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
    );
  }

  Future<void> showPhaseCompleteNotification({
    required bool wasBreak,
    required String nextPhase,
  }) async {
    await initialize();

    final title = wasBreak ? 'Перерыв завершён!' : 'Фокус-период завершён!';
    final body = wasBreak
        ? 'Время вернуться к работе!'
        : nextPhase.isNotEmpty
            ? 'Следующий: $nextPhase'
            : 'Отличная работа!';

    const androidDetails = AndroidNotificationDetails(
      'focus_complete',
      'Завершение фазы фокусировки',
      channelDescription: 'Уведомления о завершении фазы фокусировки',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      details,
    );
  }

  Future<void> cancelFocusNotifications() async {
    await _notifications.cancel(0);
    await _notifications.cancel(1);
  }

  // WakeLock для предотвращения засыпания экрана
  Future<void> enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      print('Error enabling wakelock: $e');
    }
  }

  Future<void> disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      print('Error disabling wakelock: $e');
    }
  }

  Future<bool> isWakeLockEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      print('Error checking wakelock: $e');
      return false;
    }
  }
}
