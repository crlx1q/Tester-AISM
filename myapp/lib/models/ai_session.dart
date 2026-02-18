class AiSession {
  final String id;
  final int userId;
  final String title;
  final List<String> goals;
  final List<String> keyTakeaways;
  final List<String> homework;
  final List<String> suggestedNextSteps;
  final int messagesCount;
  final int durationMinutes;
  final String? notebookEntryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiSession({
    required this.id,
    required this.userId,
    this.title = 'Сессия с AI',
    this.goals = const [],
    this.keyTakeaways = const [],
    this.homework = const [],
    this.suggestedNextSteps = const [],
    this.messagesCount = 0,
    this.durationMinutes = 0,
    this.notebookEntryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AiSession.fromJson(Map<String, dynamic> json) => AiSession(
    id: json['id'] ?? '',
    userId: json['userId'] ?? 0,
    title: json['title'] ?? 'Сессия с AI',
    goals: (json['goals'] as List?)?.map((g) => g.toString()).toList() ?? [],
    keyTakeaways: (json['keyTakeaways'] as List?)?.map((k) => k.toString()).toList() ?? [],
    homework: (json['homework'] as List?)?.map((h) => h.toString()).toList() ?? [],
    suggestedNextSteps: (json['suggestedNextSteps'] as List?)?.map((s) => s.toString()).toList() ?? [],
    messagesCount: json['messagesCount'] ?? 0,
    durationMinutes: json['durationMinutes'] ?? 0,
    notebookEntryId: json['notebookEntryId'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'goals': goals,
    'keyTakeaways': keyTakeaways,
    'homework': homework,
    'suggestedNextSteps': suggestedNextSteps,
    'messagesCount': messagesCount,
    'durationMinutes': durationMinutes,
    if (notebookEntryId != null) 'notebookEntryId': notebookEntryId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

