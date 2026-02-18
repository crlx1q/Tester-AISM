import 'package:flutter/material.dart';
import '../models/planner_schedule.dart';
import '../services/api_service.dart';

class PlannerProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  PlannerSchedule? _schedule;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  PlannerSchedule? get schedule => _schedule;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get _shouldRefresh {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > const Duration(minutes: 5);
  }

  Future<void> loadSchedule(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefresh && _schedule != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getWeekPlanner(userId);
      print('[PLANNER_PROVIDER] Result: $result');

      if (result['success'] == true) {
        // Handle nested data structure
        var plannerData = result['data'];

        if (plannerData is Map &&
            plannerData['success'] == true &&
            plannerData['data'] != null) {
          plannerData = plannerData['data'];
        }

        _schedule = PlannerSchedule.fromJson(plannerData);
        print(
            '[PLANNER_PROVIDER] Loaded schedule with ${_schedule?.tasks.length ?? 0} tasks');
        _lastUpdate = DateTime.now();
        _error = null;
      } else {
        _error = result['message'] ?? 'Ошибка загрузки плана';
      }
    } catch (e) {
      print('[PLANNER_PROVIDER] Error: $e');
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleTask(String taskId, int userId) async {
    try {
      final result = await _apiService.toggleTask(taskId, userId);

      if (result['success'] == true) {
        _schedule = PlannerSchedule.fromJson(result['data']);
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка переключения задачи: $e';
      notifyListeners();
      return false;
    }
  }

  List<PlannerTask> getTodayTasks() {
    if (_schedule == null) {
      print('[PLANNER_PROVIDER] Schedule is null');
      return [];
    }
    final today = DateTime.now();
    print(
        '[PLANNER_PROVIDER] Getting tasks for today: ${today.year}-${today.month}-${today.day}');
    final tasks = _schedule!.tasksForDate(today);
    print('[PLANNER_PROVIDER] Found ${tasks.length} tasks for today');
    return tasks;
  }

  Future<bool> generatePlan(int userId, {DateTime? targetDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result =
          await _apiService.generatePlanner(userId, targetDate: targetDate);
      print('[PLANNER_PROVIDER] Generate result: $result');

      if (result['success'] == true) {
        // Handle nested data structure: {success: true, data: {success: true, data: {...}}}
        var plannerData = result['data'];

        // Check if there's a nested success/data structure
        if (plannerData is Map &&
            plannerData['success'] == true &&
            plannerData['data'] != null) {
          plannerData = plannerData['data'];
        }

        _schedule = PlannerSchedule.fromJson(plannerData);
        print(
            '[PLANNER_PROVIDER] Generated schedule with ${_schedule?.tasks.length ?? 0} tasks');
        print(
            '[PLANNER_PROVIDER] Tasks: ${_schedule?.tasks.map((t) => "${t.title} on ${t.date}").toList()}');
        _lastUpdate = DateTime.now();
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('[PLANNER_PROVIDER] Generate error: $e');
      _error = 'Ошибка генерации плана: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<PlannerTask> getTasksForDate(DateTime date) {
    if (_schedule == null) return [];
    return _schedule!.tasksForDate(date);
  }

  Future<bool> loadWeekPlan(int userId) async {
    await loadSchedule(userId);
    return _error == null;
  }

  Future<bool> addCustomTask({
    required int userId,
    required DateTime date,
    required String title,
    String type = 'custom',
  }) async {
    try {
      final result = await _apiService.addPlannerTask(
        userId: userId,
        date: date,
        title: title,
        type: type,
      );

      if (result['success'] == true) {
        await loadSchedule(userId, forceRefresh: true);
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка добавления задачи: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId, int userId) async {
    try {
      final result = await _apiService.deletePlannerTask(taskId, userId);

      if (result['success'] == true) {
        // Remove task locally
        if (_schedule != null) {
          _schedule = PlannerSchedule(
            userId: _schedule!.userId,
            weekStart: _schedule!.weekStart,
            tasks: _schedule!.tasks.where((t) => t.id != taskId).toList(),
            createdAt: _schedule!.createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка удаления задачи: $e';
      notifyListeners();
      return false;
    }
  }

  void clearCache() {
    _schedule = null;
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }
}
