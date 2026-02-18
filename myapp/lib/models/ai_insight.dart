class InsightStats {
  final int totalStudyMinutes;
  final int scansCompleted;
  final int lecturesCompleted;
  final int quizzesTaken;
  final int averageScore;

  InsightStats({
    this.totalStudyMinutes = 0,
    this.scansCompleted = 0,
    this.lecturesCompleted = 0,
    this.quizzesTaken = 0,
    this.averageScore = 0,
  });

  factory InsightStats.fromJson(Map<String, dynamic> json) => InsightStats(
    totalStudyMinutes: json['totalStudyMinutes'] ?? 0,
    scansCompleted: json['scansCompleted'] ?? 0,
    lecturesCompleted: json['lecturesCompleted'] ?? 0,
    quizzesTaken: json['quizzesTaken'] ?? 0,
    averageScore: json['averageScore'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'totalStudyMinutes': totalStudyMinutes,
    'scansCompleted': scansCompleted,
    'lecturesCompleted': lecturesCompleted,
    'quizzesTaken': quizzesTaken,
    'averageScore': averageScore,
  };
}

class AiInsight {
  final String id;
  final int userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<String> learnedTopics;
  final List<String> weakAreas;
  final List<String> suggestedReviews;
  final String summary;
  final InsightStats stats;
  final DateTime createdAt;

  AiInsight({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    this.learnedTopics = const [],
    this.weakAreas = const [],
    this.suggestedReviews = const [],
    this.summary = '',
    InsightStats? stats,
    DateTime? createdAt,
  }) : stats = stats ?? InsightStats(),
       createdAt = createdAt ?? DateTime.now();

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
    id: json['id'] ?? '',
    userId: json['userId'] ?? 0,
    weekStart: json['weekStart'] != null ? DateTime.parse(json['weekStart']) : DateTime.now(),
    weekEnd: json['weekEnd'] != null ? DateTime.parse(json['weekEnd']) : DateTime.now(),
    learnedTopics: (json['learnedTopics'] as List?)?.map((t) => t.toString()).toList() ?? [],
    weakAreas: (json['weakAreas'] as List?)?.map((w) => w.toString()).toList() ?? [],
    suggestedReviews: (json['suggestedReviews'] as List?)?.map((s) => s.toString()).toList() ?? [],
    summary: json['summary'] ?? '',
    stats: json['stats'] != null ? InsightStats.fromJson(json['stats']) : InsightStats(),
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'weekStart': weekStart.toIso8601String(),
    'weekEnd': weekEnd.toIso8601String(),
    'learnedTopics': learnedTopics,
    'weakAreas': weakAreas,
    'suggestedReviews': suggestedReviews,
    'summary': summary,
    'stats': stats.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  String get weekLabel {
    final startDay = weekStart.day;
    final endDay = weekEnd.day;
    final monthNames = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final month = monthNames[weekStart.month - 1];
    return '$startDay-$endDay $month';
  }
}

