import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/update_info.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
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

    // Request notification permissions
    await requestNotificationPermissions();
  }

  Future<bool> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }
    return true;
  }

  Future<void> showRecordingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'recording_channel',
      'Recording Notifications',
      channelDescription: 'Notifications for ongoing recordings',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
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
      1,
      'AI-StudyMate записывает',
      'Запись лекции: 00:00',
      details,
    );

    _startRecordingTimer();
  }

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingSeconds++;
      _updateRecordingNotification();
    });
  }

  Future<void> _updateRecordingNotification() async {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');
    final timeText = '$minutes:$seconds';

    // Update every second for real-time feedback
    const androidDetails = AndroidNotificationDetails(
      'recording_channel',
      'Recording Notifications',
      channelDescription: 'Notifications for ongoing recordings',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      silent: true,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'AI-StudyMate записывает',
      'Запись лекции: $timeText',
      details,
    );
  }

  Future<void> hideRecordingNotification() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _notifications.cancel(1);
  }

  Future<void> showRecordingCompletedNotification(String duration) async {
    const androidDetails = AndroidNotificationDetails(
      'completed_channel',
      'Completed Recordings',
      channelDescription: 'Notifications for completed recordings',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
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
      2,
      'Запись завершена',
      'Длительность: $duration. Нажмите для просмотра.',
      details,
    );
  }

  Future<void> showUpdateAvailableNotification(UpdateInfo info) async {
    const androidDetails = AndroidNotificationDetails(
      'updates_channel',
      'App Updates',
      channelDescription:
          'Уведомления о доступных обновлениях приложения AI-StudyMate',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
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
      101,
      info.title,
      info.message.isNotEmpty
          ? info.message
          : 'Доступна новая версия: ${info.version}',
      details,
    );
  }
}
