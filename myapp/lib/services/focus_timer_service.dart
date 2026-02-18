import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FocusTimerService {
  static final FocusTimerService _instance = FocusTimerService._internal();
  factory FocusTimerService() => _instance;
  FocusTimerService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isBreak = false;
  Function(int)? _onTick;
  Function()? _onComplete;

  bool get isRunning => _isRunning;
  int get remainingSeconds => _remainingSeconds;
  bool get isBreak => _isBreak;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
  }

  void startTimer({
    required int seconds,
    required bool isBreak,
    Function(int)? onTick,
    Function()? onComplete,
  }) {
    _remainingSeconds = seconds;
    _totalSeconds = seconds; // Сохраняем общее время для расчета прогресса
    _isBreak = isBreak;
    _onTick = onTick;
    _onComplete = onComplete;
    _isRunning = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _onTick?.call(_remainingSeconds);
        _updateNotification();
      } else {
        stopTimer();
        _onComplete?.call();
      }
    });
  }

  void pauseTimer() {
    _isRunning = false;
    _timer?.cancel();
  }

  void resumeTimer() {
    if (_remainingSeconds > 0) {
      _isRunning = true;
      startTimer(
        seconds: _remainingSeconds,
        isBreak: _isBreak,
        onTick: _onTick,
        onComplete: _onComplete,
      );
    }
  }

  void stopTimer() {
    _isRunning = false;
    _remainingSeconds = 0;
    _timer?.cancel();
    _notifications.cancel(999); // ID уведомления таймера
  }

  int _totalSeconds = 0;

  Future<void> _updateNotification() async {
    if (!_isRunning) return;

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    // Рассчитываем прогресс - от полной шкалы до нуля
    final progress = _remainingSeconds;
    final maxProgress =
        _totalSeconds > 0 ? _totalSeconds : 1500; // 25 минут по умолчанию

    final androidDetails = AndroidNotificationDetails(
      'focus_timer_service',
      'Таймер фокусировки',
      channelDescription: 'Фоновая работа таймера фокусировки',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showProgress: true,
      progress: progress,
      maxProgress: maxProgress,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      _isBreak ? 'Перерыв' : 'Режим фокусировки',
      'Осталось: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      details,
    );
  }

  void dispose() {
    _timer?.cancel();
  }
}
