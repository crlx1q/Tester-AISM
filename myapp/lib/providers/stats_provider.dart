import 'package:flutter/material.dart';
import '../models/study_stats.dart';
import '../services/api_service.dart';

class StatsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  StudyStatsDaily? _todayStats;
  StudyStatsWeek? _weekStats;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  StudyStatsDaily? get todayStats => _todayStats;
  StudyStatsWeek? get weekStats => _weekStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cache duration: 5 minutes
  bool get _shouldRefresh {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > const Duration(minutes: 5);
  }

  Future<void> loadTodayStats(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefresh && _todayStats != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getTodayStats(userId);
      if (result['success'] == true) {
        _todayStats = StudyStatsDaily.fromJson(result['data']['data']);
        _lastUpdate = DateTime.now();
        _error = null;
      } else {
        _error = result['message'] ?? 'Ошибка загрузки статистики';
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWeekStats(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefresh && _weekStats != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getWeekStats(userId);
      if (result['success'] == true) {
        _weekStats = StudyStatsWeek.fromJson(result['data']['data'] ?? result['data']);
        _lastUpdate = DateTime.now();
        _error = null;
      } else {
        _error = result['message'] ?? 'Ошибка загрузки статистики';
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonthStats(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefresh && _weekStats != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getMonthStats(userId);
      if (result['success'] == true) {
        _weekStats = StudyStatsWeek.fromJson(result['data']['data'] ?? result['data']);
        _lastUpdate = DateTime.now();
        _error = null;
      } else {
        _error = result['message'] ?? 'Ошибка загрузки статистики';
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reportActivity(int userId, String type, {int? minutes}) async {
    try {
      await _apiService.reportActivity(
        userId: userId,
        type: type,
        minutes: minutes,
      );
      // Refresh stats after reporting
      await loadTodayStats(userId, forceRefresh: true);
    } catch (e) {
      debugPrint('Error reporting activity: $e');
    }
  }

  void clearCache() {
    _todayStats = null;
    _weekStats = null;
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }
}

