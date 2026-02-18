enum EntryType {
  scan,
  lecture,
  session,
  manual;

  String get displayName {
    switch (this) {
      case EntryType.scan:
        return 'Конспект';
      case EntryType.lecture:
        return 'Лекция';
      case EntryType.session:
        return 'Сессия';
      case EntryType.manual:
        return 'Заметка';
    }
  }
}

enum NotePriority {
  low,
  normal,
  high;

  String get displayName {
    switch (this) {
      case NotePriority.low:
        return 'Обычная';
      case NotePriority.normal:
        return 'Средняя';
      case NotePriority.high:
        return 'Важная';
    }
  }
}

class ChecklistItem {
  final String id;
  final String text;
  final bool isCompleted;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isCompleted': isCompleted,
  };

  ChecklistItem copyWith({String? text, bool? isCompleted}) {
    return ChecklistItem(
      id: id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class NotebookEntry {
  final String id;
  final int userId;
  final EntryType type;
  final String title;
  final String summary;
  final List<String> tags;
  final String course;
  final String? linkedResourceId;
  final String manualNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Новые поля для расширенного функционала
  final int? color;
  final int? icon;
  final NotePriority priority;
  final DateTime? reminderDate;
  final List<ChecklistItem> checklistItems;
  final List<String> attachments;
  final bool isPinned;

  NotebookEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.summary = '',
    this.tags = const [],
    this.course = '',
    this.linkedResourceId,
    this.manualNotes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.color,
    this.icon,
    this.priority = NotePriority.normal,
    this.reminderDate,
    this.checklistItems = const [],
    this.attachments = const [],
    this.isPinned = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory NotebookEntry.fromJson(Map<String, dynamic> json) {
    EntryType type;
    final typeStr = json['type']?.toString() ?? 'manual';
    switch (typeStr) {
      case 'scan':
        type = EntryType.scan;
        break;
      case 'lecture':
        type = EntryType.lecture;
        break;
      case 'session':
        type = EntryType.session;
        break;
      default:
        type = EntryType.manual;
    }

    NotePriority priority = NotePriority.normal;
    final priorityStr = json['priority']?.toString() ?? 'normal';
    switch (priorityStr) {
      case 'low':
        priority = NotePriority.low;
        break;
      case 'high':
        priority = NotePriority.high;
        break;
      default:
        priority = NotePriority.normal;
    }

    return NotebookEntry(
      id: json['id'] ?? '',
      userId: json['userId'] ?? 0,
      type: type,
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
      course: json['course'] ?? '',
      linkedResourceId: json['linkedResourceId'],
      manualNotes: json['manualNotes'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      color: json['color'],
      icon: json['icon'],
      priority: priority,
      reminderDate: json['reminderDate'] != null 
          ? DateTime.parse(json['reminderDate'])
          : null,
      checklistItems: (json['checklistItems'] as List?)
          ?.map((item) => ChecklistItem.fromJson(item))
          .toList() ?? [],
      attachments: (json['attachments'] as List?)?.map((a) => a.toString()).toList() ?? [],
      isPinned: json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'title': title,
    'summary': summary,
    'tags': tags,
    'course': course,
    if (linkedResourceId != null) 'linkedResourceId': linkedResourceId,
    'manualNotes': manualNotes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (color != null) 'color': color,
    if (icon != null) 'icon': icon,
    'priority': priority.name,
    if (reminderDate != null) 'reminderDate': reminderDate!.toIso8601String(),
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
    'attachments': attachments,
    'isPinned': isPinned,
  };

  NotebookEntry copyWith({
    String? title,
    String? summary,
    List<String>? tags,
    String? course,
    String? manualNotes,
    int? color,
    int? icon,
    NotePriority? priority,
    DateTime? reminderDate,
    List<ChecklistItem>? checklistItems,
    List<String>? attachments,
    bool? isPinned,
  }) {
    return NotebookEntry(
      id: id,
      userId: userId,
      type: type,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      course: course ?? this.course,
      linkedResourceId: linkedResourceId,
      manualNotes: manualNotes ?? this.manualNotes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      priority: priority ?? this.priority,
      reminderDate: reminderDate ?? this.reminderDate,
      checklistItems: checklistItems ?? this.checklistItems,
      attachments: attachments ?? this.attachments,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

