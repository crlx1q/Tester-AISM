import 'package:flutter/material.dart';
import '../models/quiz_result.dart';
import '../services/api_service.dart';

class QuizProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  QuizResult? _latestResult;
  List<QuizResult> _history = [];
  bool _isLoading = false;
  String? _error;

  QuizResult? get latestResult => _latestResult;
  List<QuizResult> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> saveResult({
    required int userId,
    required String setId,
    required String setTitle,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required int durationSeconds,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final result = await _apiService.saveQuizResult(
        userId: userId,
        setId: setId,
        setTitle: setTitle,
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        durationSeconds: durationSeconds,
        answers: answers,
      );

      if (result['success'] == true) {
        _latestResult = QuizResult.fromJson(result['data']['data']);

        // Report quiz activity and study minutes to stats
        final studyMinutes = (durationSeconds / 60).ceil();
        await _apiService.reportActivity(
          userId: userId,
          type: 'quiz',
          minutes: studyMinutes,
        );

        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка сохранения результата: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHistory(int userId, {int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getQuizHistory(userId, limit: limit);

      if (result['success'] == true) {
        final data = result['data'];
        _history =
            (data['data'] as List).map((r) => QuizResult.fromJson(r)).toList();
        _error = null;
      } else {
        _error = result['message'] ?? 'Ошибка загрузки истории';
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCache() {
    _latestResult = null;
    _history = [];
    _error = null;
    notifyListeners();
  }
}
