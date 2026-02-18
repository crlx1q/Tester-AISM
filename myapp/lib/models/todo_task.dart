import 'package:equatable/equatable.dart';

/// Приоритет задачи
enum TaskPriority {
  low,    // Низкий приоритет
  medium, // Средний приоритет
  high,   // Высокий приоритет
  urgent, // Срочная задача
}

/// Модель задачи для Todo-списка
class TodoTask extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final TaskPriority priority;
  final int progress; // 0-100
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int orderIndex; // Для сортировки после drag & drop
  final String? category; // Например: "Лекции", "Практика", "Экзамены"

  const TodoTask({
    required this.id,
    required this.title,
    this.description,
    this.deadline,
    this.priority = TaskPriority.medium,
    this.progress = 0,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.orderIndex = 0,
    this.category,
  });

  /// Копирование с изменением полей
  TodoTask copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? deadline,
    TaskPriority? priority,
    int? progress,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    int? orderIndex,
    String? category,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      orderIndex: orderIndex ?? this.orderIndex,
      category: category ?? this.category,
    );
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline?.toIso8601String(),
      'priority': priority.index,
      'progress': progress,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'orderIndex': orderIndex,
      'category': category,
    };
  }

  /// Создание из JSON
  factory TodoTask.fromJson(Map<String, dynamic> json) {
    return TodoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      priority: TaskPriority.values[json['priority'] as int? ?? 1],
      progress: json['progress'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      orderIndex: json['orderIndex'] as int? ?? 0,
      category: json['category'] as String?,
    );
  }

  /// Получить цвет по приоритету
  static int getColorByPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 0xFF10B981; // green-500
      case TaskPriority.medium:
        return 0xFF3B82F6; // blue-500
      case TaskPriority.high:
        return 0xFFF59E0B; // amber-500
      case TaskPriority.urgent:
        return 0xFFEF4444; // red-500
    }
  }

  /// Получить название приоритета
  static String getPriorityName(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Низкий';
      case TaskPriority.medium:
        return 'Средний';
      case TaskPriority.high:
        return 'Высокий';
      case TaskPriority.urgent:
        return 'Срочно';
    }
  }

  /// Получить иконку по приоритету
  static String getPriorityEmoji(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return '🟢';
      case TaskPriority.medium:
        return '🔵';
      case TaskPriority.high:
        return '🟡';
      case TaskPriority.urgent:
        return '🔴';
    }
  }

  /// Проверка, просрочена ли задача
  bool get isOverdue {
    if (deadline == null || isCompleted) return false;
    return DateTime.now().isAfter(deadline!);
  }

  /// Сколько дней до дедлайна
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final difference = deadline!.difference(DateTime.now());
    return difference.inDays;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        deadline,
        priority,
        progress,
        isCompleted,
        createdAt,
        completedAt,
        orderIndex,
        category,
      ];
}

