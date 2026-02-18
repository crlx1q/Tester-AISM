enum TaskType {
  reviewLecture,
  reviewScan,
  quiz,
  reading,
  custom;

  static TaskType fromString(String value) {
    switch (value) {
      case 'review_lecture':
        return TaskType.reviewLecture;
      case 'review_scan':
        return TaskType.reviewScan;
      case 'quiz':
        return TaskType.quiz;
      case 'reading':
        return TaskType.reading;
      default:
        return TaskType.custom;
    }
  }

  String toServerString() {
    switch (this) {
      case TaskType.reviewLecture:
        return 'review_lecture';
      case TaskType.reviewScan:
        return 'review_scan';
      case TaskType.quiz:
        return 'quiz';
      case TaskType.reading:
        return 'reading';
      case TaskType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case TaskType.reviewLecture:
        return 'Повторить лекцию';
      case TaskType.reviewScan:
        return 'Повторить конспект';
      case TaskType.quiz:
        return 'Пройти квиз';
      case TaskType.reading:
        return 'Чтение';
      case TaskType.custom:
        return 'Задача';
    }
  }
}

enum TaskPriority {
  low,
  medium,
  high;

  static TaskPriority fromString(String value) {
    switch (value) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }
}

class PlannerTask {
  final String id;
  final DateTime date;
  final String title;
  final TaskType type;
  final String? relatedNotebookId;
  final bool completed;
  final String? dueTime;
  final TaskPriority priority;

  PlannerTask({
    required this.id,
    required this.date,
    required this.title,
    this.type = TaskType.custom,
    this.relatedNotebookId,
    this.completed = false,
    this.dueTime,
    this.priority = TaskPriority.medium,
  });

  factory PlannerTask.fromJson(Map<String, dynamic> json) => PlannerTask(
    id: json['id'] ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    title: json['title'] ?? '',
    type: TaskType.fromString(json['type'] ?? 'custom'),
    relatedNotebookId: json['relatedNotebookId'],
    completed: json['completed'] ?? false,
    dueTime: json['dueTime'],
    priority: TaskPriority.fromString(json['priority'] ?? 'medium'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'title': title,
    'type': type.toServerString(),
    if (relatedNotebookId != null) 'relatedNotebookId': relatedNotebookId,
    'completed': completed,
    if (dueTime != null) 'dueTime': dueTime,
    'priority': priority.name,
  };

  PlannerTask copyWith({bool? completed}) {
    return PlannerTask(
      id: id,
      date: date,
      title: title,
      type: type,
      relatedNotebookId: relatedNotebookId,
      completed: completed ?? this.completed,
      dueTime: dueTime,
      priority: priority,
    );
  }
}

class PlannerSchedule {
  final int userId;
  final DateTime weekStart;
  final List<PlannerTask> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlannerSchedule({
    required this.userId,
    required this.weekStart,
    this.tasks = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PlannerSchedule.fromJson(Map<String, dynamic> json) => PlannerSchedule(
    userId: json['userId'] ?? 0,
    weekStart: json['weekStart'] != null ? DateTime.parse(json['weekStart']) : DateTime.now(),
    tasks: (json['tasks'] as List?)?.map((t) => PlannerTask.fromJson(t)).toList() ?? [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'weekStart': weekStart.toIso8601String(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  List<PlannerTask> tasksForDate(DateTime date) {
    return tasks.where((task) => 
      task.date.year == date.year &&
      task.date.month == date.month &&
      task.date.day == date.day
    ).toList();
  }

  int get completedTasksCount => tasks.where((t) => t.completed).length;
  int get totalTasksCount => tasks.length;
  double get completionPercentage {
    if (totalTasksCount == 0) return 0;
    return (completedTasksCount / totalTasksCount) * 100;
  }
}

