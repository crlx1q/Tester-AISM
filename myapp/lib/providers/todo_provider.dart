import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_task.dart';

/// Provider для управления списком задач
class TodoProvider extends ChangeNotifier {
  List<TodoTask> _tasks = [];
  String _filterCategory = 'Все';
  bool _showCompleted = true;

  List<TodoTask> get tasks => _tasks;
  String get filterCategory => _filterCategory;
  bool get showCompleted => _showCompleted;

  /// Получить задачи с фильтрацией
  List<TodoTask> get filteredTasks {
    var filtered = _tasks.where((task) {
      // Фильтр по категории
      if (_filterCategory != 'Все' && task.category != _filterCategory) {
        return false;
      }
      // Фильтр по завершенности
      if (!_showCompleted && task.isCompleted) {
        return false;
      }
      return true;
    }).toList();

    // Сортировка: незавершенные сначала, потом по orderIndex
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.orderIndex.compareTo(b.orderIndex);
    });

    return filtered;
  }

  /// Получить все категории
  List<String> get categories {
    final categorySet = <String>{'Все'};
    for (var task in _tasks) {
      if (task.category != null && task.category!.isNotEmpty) {
        categorySet.add(task.category!);
      }
    }
    return categorySet.toList();
  }

  /// Статистика
  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.isCompleted).length;
  int get activeTasks => _tasks.where((t) => !t.isCompleted).length;
  int get overdueTasks => _tasks.where((t) => t.isOverdue).length;

  double get completionPercentage {
    if (_tasks.isEmpty) return 0;
    return (completedTasks / totalTasks) * 100;
  }

  TodoProvider() {
    loadTasks();
  }

  /// Загрузка задач из локального хранилища
  Future<void> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('todo_tasks');
      if (tasksJson != null) {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        _tasks = decoded.map((json) => TodoTask.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  /// Сохранение задач в локальное хранилище
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString('todo_tasks', tasksJson);
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  /// Добавление новой задачи
  Future<void> addTask(TodoTask task) async {
    final newTask = task.copyWith(
      orderIndex: _tasks.length,
    );
    _tasks.add(newTask);
    await _saveTasks();
    notifyListeners();
  }

  /// Обновление задачи
  Future<void> updateTask(TodoTask updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      await _saveTasks();
      notifyListeners();
    }
  }

  /// Удаление задачи
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    // Пересчитать orderIndex
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i] = _tasks[i].copyWith(orderIndex: i);
    }
    await _saveTasks();
    notifyListeners();
  }

  /// Переключение статуса завершенности
  Future<void> toggleTaskCompletion(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      await _saveTasks();
      notifyListeners();
    }
  }

  /// Обновление прогресса задачи
  Future<void> updateTaskProgress(String taskId, int progress) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final newProgress = progress.clamp(0, 100);
      _tasks[index] = task.copyWith(
        progress: newProgress,
        isCompleted: newProgress == 100,
        completedAt: newProgress == 100 ? DateTime.now() : null,
      );
      await _saveTasks();
      notifyListeners();
    }
  }

  /// Изменение порядка задач (drag & drop)
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final filteredList = filteredTasks;
    if (oldIndex >= filteredList.length || newIndex >= filteredList.length) {
      return;
    }

    final item = filteredList.removeAt(oldIndex);
    filteredList.insert(newIndex, item);

    // Обновить orderIndex для всех задач
    for (int i = 0; i < filteredList.length; i++) {
      final taskIndex = _tasks.indexWhere((t) => t.id == filteredList[i].id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = _tasks[taskIndex].copyWith(orderIndex: i);
      }
    }

    await _saveTasks();
    notifyListeners();
  }

  /// Установить фильтр по категории
  void setFilterCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  /// Переключить отображение завершенных задач
  void toggleShowCompleted() {
    _showCompleted = !_showCompleted;
    notifyListeners();
  }

  /// Удалить все завершенные задачи
  Future<void> clearCompletedTasks() async {
    _tasks.removeWhere((t) => t.isCompleted);
    // Пересчитать orderIndex
    for (int i = 0; i < _tasks.length; i++) {
      _tasks[i] = _tasks[i].copyWith(orderIndex: i);
    }
    await _saveTasks();
    notifyListeners();
  }

  /// Получить задачи по категории
  List<TodoTask> getTasksByCategory(String category) {
    return _tasks.where((t) => t.category == category).toList();
  }

  /// Получить просроченные задачи
  List<TodoTask> getOverdueTasks() {
    return _tasks.where((t) => t.isOverdue).toList();
  }

  /// Получить задачи на сегодня
  List<TodoTask> getTodayTasks() {
    final today = DateTime.now();
    return _tasks.where((t) {
      if (t.deadline == null) return false;
      return t.deadline!.year == today.year &&
          t.deadline!.month == today.month &&
          t.deadline!.day == today.day;
    }).toList();
  }

  /// Получить задачи на эту неделю
  List<TodoTask> getWeekTasks() {
    final today = DateTime.now();
    final weekEnd = today.add(const Duration(days: 7));
    return _tasks.where((t) {
      if (t.deadline == null) return false;
      return t.deadline!.isAfter(today) && t.deadline!.isBefore(weekEnd);
    }).toList();
  }
}

