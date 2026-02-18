import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_session.dart';
import '../services/focus_timer_service.dart';

enum FocusTimerState {
  idle,
  running,
  paused,
}

class FocusProvider with ChangeNotifier {
  FocusSession? _currentSession;
  FocusTimerState _timerState = FocusTimerState.idle;
  int _remainingSeconds = 0;
  Timer? _timer;
  FocusSettings _settings = const FocusSettings();
  List<FocusSession> _history = [];
  final FocusTimerService _timerService = FocusTimerService();

  FocusSession? get currentSession => _currentSession;
  FocusTimerState get timerState => _timerState;
  int get remainingSeconds => _remainingSeconds;
  FocusSettings get settings => _settings;
  List<FocusSession> get history => _history;

  int get currentCycle =>
      _currentSession?.completedCycles ??
      0 + (_currentSession?.isBreak == false ? 1 : 0);
  int get totalCycles => _currentSession?.totalCycles ?? 0;

  FocusProvider() {
    _loadSettings();
    _loadHistory();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('focus_settings');
      if (settingsJson != null) {
        _settings = FocusSettings.fromJson(jsonDecode(settingsJson));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading focus settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('focus_settings', jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Error saving focus settings: $e');
    }
  }

  Future<void> updateSettings(FocusSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('focus_history') ?? [];
      _history = historyJson
          .map((json) => FocusSession.fromJson(jsonDecode(json)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          _history.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList('focus_history', historyJson);
    } catch (e) {
      debugPrint('Error saving focus history: $e');
    }
  }

  void startSession({int? cycles}) {
    if (_timerState != FocusTimerState.idle) return;

    _currentSession = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      focusDuration: _settings.focusDuration,
      breakDuration: _settings.shortBreakDuration,
      totalCycles: cycles ?? _settings.cyclesBeforeLongBreak,
      completedCycles: 0,
      isBreak: false,
    );

    _remainingSeconds = _settings.focusDuration * 60;
    _timerState = FocusTimerState.running;
    _startTimer();
    notifyListeners();
  }

  void pauseTimer() {
    if (_timerState != FocusTimerState.running) return;
    _timer?.cancel();
    _timerState = FocusTimerState.paused;
    notifyListeners();
  }

  void resumeTimer() {
    if (_timerState != FocusTimerState.paused) return;
    _timerState = FocusTimerState.running;
    _startTimer();
    notifyListeners();
  }

  void stopSession() {
    _timer?.cancel();
    _timerService
        .stopTimer(); // Останавливаем фоновый сервис и удаляем уведомление
    if (_currentSession != null) {
      final completedSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        isCompleted: false,
      );
      _history.insert(0, completedSession);
      _saveHistory();
    }
    _currentSession = null;
    _timerState = FocusTimerState.idle;
    _remainingSeconds = 0;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();

    // Используем фоновый сервис для надежной работы таймера
    _timerService.startTimer(
      seconds: _remainingSeconds,
      isBreak: _currentSession?.isBreak ?? false,
      onTick: (remaining) {
        _remainingSeconds = remaining;

        // Обновляем общее время фокусировки
        if (_currentSession != null && !_currentSession!.isBreak) {
          _currentSession = _currentSession!.copyWith(
            totalFocusTime: _currentSession!.totalFocusTime + 1,
          );
        }

        notifyListeners();
      },
      onComplete: () {
        _onTimerComplete();
      },
    );

    // Также запускаем локальный таймер для синхронизации
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;

        // Обновляем общее время фокусировки
        if (_currentSession != null && !_currentSession!.isBreak) {
          _currentSession = _currentSession!.copyWith(
            totalFocusTime: _currentSession!.totalFocusTime + 1,
          );
        }

        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();

    if (_currentSession == null) return;

    if (_currentSession!.isBreak) {
      // Перерыв закончен, начинаем новый цикл фокуса
      final newCompletedCycles = _currentSession!.completedCycles + 1;

      if (newCompletedCycles >= _currentSession!.totalCycles) {
        // Все циклы завершены
        final completedSession = _currentSession!.copyWith(
          endTime: DateTime.now(),
          isCompleted: true,
          completedCycles: newCompletedCycles,
        );
        _history.insert(0, completedSession);
        _saveHistory();
        _currentSession = null;
        _timerState = FocusTimerState.idle;
        _remainingSeconds = 0;
      } else {
        // Начинаем новый фокус-период
        _currentSession = _currentSession!.copyWith(
          isBreak: false,
          completedCycles: newCompletedCycles,
        );
        _remainingSeconds = _settings.focusDuration * 60;
        _startTimer();
      }
    } else {
      // Фокус-период закончен, начинаем перерыв
      final isLongBreak = (_currentSession!.completedCycles + 1) %
              _settings.cyclesBeforeLongBreak ==
          0;

      final breakDuration = isLongBreak
          ? _settings.longBreakDuration
          : _settings.shortBreakDuration;

      _currentSession = _currentSession!.copyWith(
        isBreak: true,
      );
      _remainingSeconds = breakDuration * 60;
      _startTimer();
    }

    notifyListeners();
  }

  void skipToNextPhase() {
    if (_currentSession == null) return;
    _remainingSeconds = 0;
    _onTimerComplete();
  }

  // Статистика
  int get todayFocusTime {
    final today = DateTime.now();
    return _history
        .where((session) =>
            session.startTime.year == today.year &&
            session.startTime.month == today.month &&
            session.startTime.day == today.day)
        .fold(0, (sum, session) => sum + session.totalFocusTime);
  }

  int get weekFocusTime {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _history
        .where((session) => session.startTime.isAfter(weekStart))
        .fold(0, (sum, session) => sum + session.totalFocusTime);
  }

  int get totalCompletedSessions {
    return _history.where((session) => session.isCompleted).length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerService.stopTimer();
    super.dispose();
  }
}
