import 'package:flutter/material.dart';
import '../models/ai_insight.dart';
import '../services/api_service.dart';

class InsightsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  AiInsight? _latestInsight;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  AiInsight? get latestInsight => _latestInsight;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get _shouldRefresh {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > const Duration(hours: 1);
  }

  Future<void> loadLatestInsight(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && !_shouldRefresh && _latestInsight != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getLatestInsights(userId);

      if (result['success'] == true) {
        _latestInsight = AiInsight.fromJson(result['data']['data']);
        _lastUpdate = DateTime.now();
        _error = null;
      } else {
        // No insights yet, try to generate
        if (result['message']?.contains('не созданы') == true) {
          await generateInsight(userId);
        } else {
          _error = result['message'] ?? 'Ошибка загрузки инсайтов';
        }
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateInsight(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.generateInsights(userId);

      if (result['success'] == true) {
        _latestInsight = AiInsight.fromJson(result['data']['data']);
        _lastUpdate = DateTime.now();
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка генерации инсайтов: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearCache() {
    _latestInsight = null;
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }
}

