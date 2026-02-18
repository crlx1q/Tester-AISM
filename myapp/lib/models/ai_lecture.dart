class AiLecture {
  final String id;
  final int userId;
  final String? recordingId;
  final String title;
  final int durationSeconds;
  final String transcription;
  final String summary;
  final List<String> keyConcepts;
  final List<String> questions;
  final List<String> tags;
  final String course;
  final String? notebookEntryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiLecture({
    required this.id,
    required this.userId,
    this.recordingId,
    required this.title,
    this.durationSeconds = 0,
    this.transcription = '',
    this.summary = '',
    this.keyConcepts = const [],
    this.questions = const [],
    this.tags = const [],
    this.course = '',
    this.notebookEntryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AiLecture.fromJson(Map<String, dynamic> json) => AiLecture(
    id: json['id'] ?? '',
    userId: json['userId'] ?? 0,
    recordingId: json['recordingId'],
    title: json['title'] ?? '',
    durationSeconds: json['durationSeconds'] ?? 0,
    transcription: json['transcription'] ?? '',
    summary: json['summary'] ?? '',
    keyConcepts: (json['keyConcepts'] as List?)?.map((k) => k.toString()).toList() ?? [],
    questions: (json['questions'] as List?)?.map((q) => q.toString()).toList() ?? [],
    tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
    course: json['course'] ?? '',
    notebookEntryId: json['notebookEntryId'],
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    if (recordingId != null) 'recordingId': recordingId,
    'title': title,
    'durationSeconds': durationSeconds,
    'transcription': transcription,
    'summary': summary,
    'keyConcepts': keyConcepts,
    'questions': questions,
    'tags': tags,
    'course': course,
    if (notebookEntryId != null) 'notebookEntryId': notebookEntryId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}м ${seconds}с';
  }
}

