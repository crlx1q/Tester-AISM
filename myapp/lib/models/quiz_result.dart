class QuizAnswer {
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int? timeSpent; // seconds

  QuizAnswer({
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.timeSpent,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'userAnswer': userAnswer,
    'correctAnswer': correctAnswer,
    'isCorrect': isCorrect,
    if (timeSpent != null) 'timeSpent': timeSpent,
  };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) => QuizAnswer(
    question: json['question'] ?? '',
    userAnswer: json['userAnswer'] ?? '',
    correctAnswer: json['correctAnswer'] ?? '',
    isCorrect: json['isCorrect'] ?? false,
    timeSpent: json['timeSpent'],
  );
}

class QuizResult {
  final String id;
  final int userId;
  final String setId;
  final String setTitle;
  final int score; // 0-100
  final int totalQuestions;
  final int correctAnswers;
  final int durationSeconds;
  final List<QuizAnswer> answers;
  final DateTime createdAt;

  QuizResult({
    required this.id,
    required this.userId,
    required this.setId,
    required this.setTitle,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.durationSeconds,
    required this.answers,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'setId': setId,
    'setTitle': setTitle,
    'score': score,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'durationSeconds': durationSeconds,
    'answers': answers.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    id: json['id'] ?? '',
    userId: json['userId'] ?? 0,
    setId: json['setId'] ?? '',
    setTitle: json['setTitle'] ?? 'Безымянный набор',
    score: json['score'] ?? 0,
    totalQuestions: json['totalQuestions'] ?? 0,
    correctAnswers: json['correctAnswers'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0,
    answers: (json['answers'] as List?)
        ?.map((a) => QuizAnswer.fromJson(a))
        .toList() ?? [],
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}м ${seconds}с';
  }

  String get averageTimePerQuestion {
    if (totalQuestions == 0) return '0с';
    final avgSeconds = durationSeconds ~/ totalQuestions;
    return '${avgSeconds}с';
  }

  double get scorePercentage => score.toDouble();
}

