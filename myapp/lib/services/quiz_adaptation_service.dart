import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quiz_level.dart';
import '../models/study_set.dart';
import 'api_service.dart';

class QuizAdaptationService {
  final ApiService _apiService = ApiService();

  /// Получить текущий прогресс по теме
  Future<QuizProgress?> getProgress(int userId, String topic) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/quiz-progress/$userId/${Uri.encodeComponent(topic)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && result['data'] != null) {
          return QuizProgress.fromJson(result['data']);
        }
      }
      return null;
    } catch (e) {
      print('[QuizAdaptation] Error getting progress: $e');
      return null;
    }
  }

  /// Сохранить прогресс по теме
  Future<bool> saveProgress(QuizProgress progress) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/quiz-progress'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(progress.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('[QuizAdaptation] Error saving progress: $e');
      return false;
    }
  }

  /// Получить адаптивные вопросы для уровня
  Future<List<StudyCard>> getAdaptiveQuestions({
    required int userId,
    required String topic,
    required int level,
    required List<StudyCard> allCards,
    required Map<String, int> errorCounts,
    int count = 10,
  }) async {
    print('[QuizAdaptation] Getting adaptive questions - Level: $level, Topic: $topic, Total cards: ${allCards.length}');
    try {
      // Отсортировать карточки по частоте ошибок
      final sortedCards = List<StudyCard>.from(allCards);
      sortedCards.sort((a, b) {
        final aErrors = errorCounts[a.term] ?? 0;
        final bErrors = errorCounts[b.term] ?? 0;
        return bErrors.compareTo(aErrors); // Больше ошибок = выше в списке
      });

      // Выбрать карточки в зависимости от уровня
      List<StudyCard> selectedCards;
      
      if (level <= 2) {
        // Низкий уровень - больше простых карточек (меньше ошибок)
        final easyCards = sortedCards.where((c) => (errorCounts[c.term] ?? 0) <= 1).toList();
        selectedCards = easyCards.length >= count 
            ? easyCards.take(count).toList()
            : easyCards + sortedCards.where((c) => !easyCards.contains(c)).take(count - easyCards.length).toList();
      } else if (level >= 4) {
        // Высокий уровень - больше сложных карточек (больше ошибок)
        final hardCards = sortedCards.where((c) => (errorCounts[c.term] ?? 0) >= 2).toList();
        selectedCards = hardCards.length >= count
            ? hardCards.take(count).toList()
            : hardCards + sortedCards.where((c) => !hardCards.contains(c)).take(count - hardCards.length).toList();
      } else {
        // Средний уровень - смешанный набор
        selectedCards = sortedCards.take(count).toList();
      }

      // Если запросили через API для дополнительной адаптации
      if (selectedCards.length < count) {
        try {
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/quiz-adaptive'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'topic': topic,
              'level': level,
              'availableCards': allCards.map((c) => c.toJson()).toList(),
              'errorCounts': errorCounts,
              'count': count,
            }),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result['success'] == true && result['data'] != null) {
              final adaptiveCards = (result['data']['cards'] as List)
                  .map((c) => StudyCard.fromJson(c))
                  .toList();
              if (adaptiveCards.isNotEmpty) {
                return adaptiveCards;
              }
            }
          }
        } catch (e) {
          print('[QuizAdaptation] Error getting adaptive questions from API: $e');
        }
      }

      // Перемешать выбранные карточки
      selectedCards.shuffle();
      return selectedCards;
    } catch (e) {
      print('[QuizAdaptation] Error: $e');
      // Fallback - вернуть случайные карточки
      return List<StudyCard>.from(allCards)..shuffle()..take(count).toList();
    }
  }

  /// Обновить прогресс после квиза
  Future<QuizProgress> updateProgressAfterQuiz({
    required int userId,
    required String topic,
    required int currentLevel,
    required int correctAnswers,
    required int totalQuestions,
    required Map<String, bool> results, // карточка -> правильно/неправильно
    required Map<String, int> previousErrorCounts,
  }) async {
    // Получить текущий прогресс
    final existingProgress = await getProgress(userId, topic);
    
    final oldCorrect = existingProgress?.correctAnswers ?? 0;
    final oldTotal = existingProgress?.totalQuestions ?? 0;
    
    final newCorrect = oldCorrect + correctAnswers;
    final newTotal = oldTotal + totalQuestions;
    final newMastery = newTotal > 0 ? newCorrect / newTotal : 0.0;

    // Обновить счетчики ошибок
    final updatedErrorCounts = Map<String, int>.from(previousErrorCounts);
    results.forEach((cardTerm, isCorrect) {
      if (!isCorrect) {
        updatedErrorCounts[cardTerm] = (updatedErrorCounts[cardTerm] ?? 0) + 1;
      }
    });

    // Вычислить следующий уровень
    final nextLevel = existingProgress?.calculateNextLevel(correctAnswers, totalQuestions) ?? currentLevel;

    final progress = QuizProgress(
      userId: userId.toString(),
      topic: topic,
      currentLevel: nextLevel,
      masteryScore: newMastery,
      totalQuestions: newTotal,
      correctAnswers: newCorrect,
      lastUpdated: DateTime.now(),
      errorCounts: updatedErrorCounts,
    );

    await saveProgress(progress);
    return progress;
  }
}
