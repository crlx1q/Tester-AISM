class AiScanNote {
  final String id;
  final int userId;
  final String title;
  final String? imageUrl;
  final String summary;
  final List<String> keyPoints;
  final List<String> concepts;
  final List<String> formulas;
  final List<String> questions;
  final String subject;
  final List<String> tags;
  final String course;
  final String manualNotes;
  final bool favorite;
  final String? notebookEntryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiScanNote({
    required this.id,
    required this.userId,
    required this.title,
    this.imageUrl,
    this.summary = '',
    this.keyPoints = const [],
    this.concepts = const [],
    this.formulas = const [],
    this.questions = const [],
    this.subject = '',
    this.tags = const [],
    this.course = '',
    this.manualNotes = '',
    this.favorite = false,
    this.notebookEntryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AiScanNote.fromJson(Map<String, dynamic> json) => AiScanNote(
    id: json['id'] ?? '',
    userId: json['userId'] ?? 0,
    title: json['title'] ?? '',
    imageUrl: json['imageUrl'],
    summary: json['summary'] ?? '',
    keyPoints: (json['keyPoints'] as List?)?.map((k) => k.toString()).toList() ?? [],
    concepts: (json['concepts'] as List?)?.map((c) => c.toString()).toList() ?? [],
    formulas: (json['formulas'] as List?)?.map((f) => f.toString()).toList() ?? [],
    questions: (json['questions'] as List?)?.map((q) => q.toString()).toList() ?? [],
    subject: json['subject'] ?? '',
    tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
    course: json['course'] ?? '',
    manualNotes: json['manualNotes'] ?? '',
    favorite: json['favorite'] ?? false,
    notebookEntryId: json['notebookEntryId'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'summary': summary,
    'keyPoints': keyPoints,
    'concepts': concepts,
    'formulas': formulas,
    'questions': questions,
    'subject': subject,
    'tags': tags,
    'course': course,
    'manualNotes': manualNotes,
    'favorite': favorite,
    if (notebookEntryId != null) 'notebookEntryId': notebookEntryId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

