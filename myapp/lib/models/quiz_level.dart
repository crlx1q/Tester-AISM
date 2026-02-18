import '../models/study_set.dart';

class QuizLevel {
  final String topic; // Например, "История Казахстана — Средневековье"
  final int level; // Уровень сложности 1-5
  final int questionCount; // Количество вопросов (по умолчанию 10)
  final List<StudyCard> cards; // Карточки для этого уровня
  final String? description;

  QuizLevel({
    required this.topic,
    required this.level,
    required this.cards,
    this.questionCount = 10,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'level': level,
    'questionCount': questionCount,
    'cards': cards.map((c) => c.toJson()).toList(),
    if (description != null) 'description': description,
  };

  factory QuizLevel.fromJson(Map<String, dynamic> json) {
    return QuizLevel(
      topic: json['topic'] ?? '',
      level: json['level'] ?? 1,
      questionCount: json['questionCount'] ?? 10,
      cards: (json['cards'] as List? ?? []).map((c) => StudyCard.fromJson(c)).toList(),
      description: json['description'],
    );
  }
}

class QuizProgress {
  final String userId;
  final String topic;
  final int currentLevel; // Текущий уровень сложности
  final double masteryScore; // 0.0 - 1.0, насколько хорошо знает тему
  final int totalQuestions;
  final int correctAnswers;
  final DateTime lastUpdated;
  final Map<String, int> errorCounts; // Сколько раз ошибся в каждой карточке

  QuizProgress({
    required this.userId,
    required this.topic,
    required this.currentLevel,
    required this.masteryScore,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    required this.lastUpdated,
    this.errorCounts = const {},
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'topic': topic,
    'currentLevel': currentLevel,
    'masteryScore': masteryScore,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'lastUpdated': lastUpdated.toIso8601String(),
    'errorCounts': errorCounts,
  };

  factory QuizProgress.fromJson(Map<String, dynamic> json) {
    return QuizProgress(
      userId: json['userId']?.toString() ?? '',
      topic: json['topic'] ?? '',
      currentLevel: json['currentLevel'] ?? 1,
      masteryScore: (json['masteryScore'] ?? 0.0).toDouble(),
      totalQuestions: json['totalQuestions'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : DateTime.now(),
      errorCounts: json['errorCounts'] != null 
          ? Map<String, int>.from(json['errorCounts'])
          : {},
    );
  }

  // Вычислить следующий уровень на основе результатов
  int calculateNextLevel(int newCorrect, int newTotal) {
    final newMastery = (correctAnswers + newCorrect) / (totalQuestions + newTotal);
    
    if (newMastery >= 0.9 && currentLevel < 5) {
      return currentLevel + 1;
    } else if (newMastery < 0.5 && currentLevel > 1) {
      return currentLevel - 1;
    }
    return currentLevel;
  }
}
