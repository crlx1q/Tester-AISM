class StudyStatsDaily {
  final int userId;
  final DateTime date;
  final int studyMinutes;
  final int scansCount;
  final int recordingsCount;
  final int chatSessionsCount;
  final int cardsCreated;
  final int quizzesTaken;
  final DateTime updatedAt;

  StudyStatsDaily({
    required this.userId,
    required this.date,
    this.studyMinutes = 0,
    this.scansCount = 0,
    this.recordingsCount = 0,
    this.chatSessionsCount = 0,
    this.cardsCreated = 0,
    this.quizzesTaken = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory StudyStatsDaily.fromJson(Map<String, dynamic> json) => StudyStatsDaily(
    userId: json['userId'] ?? 0,
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    studyMinutes: json['studyMinutes'] ?? 0,
    scansCount: json['scansCount'] ?? 0,
    recordingsCount: json['recordingsCount'] ?? 0,
    chatSessionsCount: json['chatSessionsCount'] ?? 0,
    cardsCreated: json['cardsCreated'] ?? 0,
    quizzesTaken: json['quizzesTaken'] ?? 0,
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'])
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'date': date.toIso8601String(),
    'studyMinutes': studyMinutes,
    'scansCount': scansCount,
    'recordingsCount': recordingsCount,
    'chatSessionsCount': chatSessionsCount,
    'cardsCreated': cardsCreated,
    'quizzesTaken': quizzesTaken,
    'updatedAt': updatedAt.toIso8601String(),
  };

  int get totalActivities => scansCount + recordingsCount + chatSessionsCount + quizzesTaken;
}

class StudyStatsWeek {
  final int totalStudyMinutes;
  final int totalScans;
  final int totalRecordings;
  final int totalChatSessions;
  final int totalCardsCreated;
  final int totalQuizzes;
  final List<StudyStatsDaily> dailyStats;

  StudyStatsWeek({
    this.totalStudyMinutes = 0,
    this.totalScans = 0,
    this.totalRecordings = 0,
    this.totalChatSessions = 0,
    this.totalCardsCreated = 0,
    this.totalQuizzes = 0,
    this.dailyStats = const [],
  });

  factory StudyStatsWeek.fromJson(Map<String, dynamic> json) => StudyStatsWeek(
    totalStudyMinutes: json['totalStudyMinutes'] ?? 0,
    totalScans: json['totalScans'] ?? 0,
    totalRecordings: json['totalRecordings'] ?? 0,
    totalChatSessions: json['totalChatSessions'] ?? 0,
    totalCardsCreated: json['totalCardsCreated'] ?? 0,
    totalQuizzes: json['totalQuizzes'] ?? 0,
    dailyStats: (json['dailyStats'] as List?)
        ?.map((d) => StudyStatsDaily.fromJson(d))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'totalStudyMinutes': totalStudyMinutes,
    'totalScans': totalScans,
    'totalRecordings': totalRecordings,
    'totalChatSessions': totalChatSessions,
    'totalCardsCreated': totalCardsCreated,
    'totalQuizzes': totalQuizzes,
    'dailyStats': dailyStats.map((d) => d.toJson()).toList(),
  };

  int get totalActivities => totalScans + totalRecordings + totalChatSessions + totalQuizzes;
  
  double get averageStudyMinutesPerDay {
    if (dailyStats.isEmpty) return 0;
    return totalStudyMinutes / dailyStats.length;
  }
}

