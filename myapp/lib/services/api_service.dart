import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_prefs.dart';

class ApiService {
  // Используйте реальный IP адрес вашего ПК для подключения с телефона
  // Замените на ваш IP: 192.168.3.7 (Wi-Fi) или 192.168.100.13 (Ethernet)
  static const String _baseUrl = 'https://your-api-domain.com';
  static const Duration _timeout =
      Duration(seconds: 30); // Увеличен для больших запросов
  static const Duration _longTimeout =
      Duration(minutes: 2); // Для AI операций с изображениями/аудио

  static String get baseUrl => _baseUrl;

  static Uri buildWebSocketUri(String path) {
    final httpUri = Uri.parse(_baseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: path,
    );
  }

  // Получение статуса сервера (версия, новости, состояние)
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      print('Fetching server health...');
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('Health check response: ${response.statusCode}');
      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': body};
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Не удалось получить статус сервера',
        };
      }
    } catch (e) {
      print('Server health request failed: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // Проверка подключения к серверу
  Future<bool> checkServerConnection() async {
    final result = await getHealthStatus();
    return result['success'] == true;
  }

  Future<Map<String, dynamic>> register(String name, String email,
      String password, String verificationCode) async {
    try {
      print('Attempting to register user: $email');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'verificationCode': verificationCode
            }),
          )
          .timeout(_timeout);

      print('Registration response status: ${response.statusCode}');
      print('Registration response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('Attempting to login user: $email');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // Обновление аватарки пользователя
  Future<Map<String, dynamic>> updateAvatar(
      int userId, String avatarBase64) async {
    try {
      print('Updating avatar for user: $userId');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/profile/avatar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'avatarBase64': avatarBase64}),
          )
          .timeout(_timeout);

      print('Avatar update response status: ${response.statusCode}');
      print('Avatar update response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Avatar update error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // Получение данных пользователя
  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      print('Getting user profile: $userId');
      final response = await http.get(
        Uri.parse('$_baseUrl/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      print('Get profile response status: ${response.statusCode}');
      print('Get profile response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Get profile error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // Обновление имени пользователя
  Future<Map<String, dynamic>> updateUserName(int userId, String name) async {
    try {
      print('Updating user name: $userId -> $name');
      final response = await http
          .put(
            Uri.parse('$_baseUrl/profile/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(_timeout);

      print('Update name response status: ${response.statusCode}');
      print('Update name response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Update name error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // Регистрация: запрос проверочного кода
  Future<Map<String, dynamic>> requestRegistrationCode(String email) async {
    try {
      print('Requesting registration code for email: $email');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/request-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);

      print('Request code response status: ${response.statusCode}');
      print('Request code response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Request code error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> changePassword(
      int userId, String currentPassword, String newPassword) async {
    try {
      print('Changing password for user: $userId');
      final response = await http
          .put(
            Uri.parse('$_baseUrl/profile/$userId/password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      print('Change password response status: ${response.statusCode}');
      print('Change password response body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Change password error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> requestPasswordResetCode(String email) async {
    try {
      print('Requesting password reset code for email: $email');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/reset-password/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);

      print('Reset password request status: ${response.statusCode}');
      print('Reset password request body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Reset password request error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset(
      String email, String code, String newPassword) async {
    try {
      print('Confirming password reset for email: $email');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/reset-password/confirm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'email': email, 'code': code, 'newPassword': newPassword}),
          )
          .timeout(_timeout);

      print('Confirm reset status: ${response.statusCode}');
      print('Confirm reset body: ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('Confirm reset error: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // ---------- AI: Usage/Streak/History ----------
  Future<Map<String, dynamic>> getAiUsage(int userId, {String? feature}) async {
    try {
      final uri = Uri.parse('$_baseUrl/ai/usage/$userId').replace(
          queryParameters: feature != null ? {'feature': feature} : null);
      final res = await http.get(uri,
          headers: {'Content-Type': 'application/json'}).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Не удалось получить лимиты'
      };
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> getAiHistory(int userId,
      {String? feature, int? limit}) async {
    try {
      final params = <String, String>{};
      if (feature != null) params['feature'] = feature;
      if (limit != null) params['limit'] = '$limit';
      final uri = Uri.parse('$_baseUrl/ai/history/$userId')
          .replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri,
          headers: {'Content-Type': 'application/json'}).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': body['data'], 'ai': body['ai']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Не удалось получить историю'
      };
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  Future<Map<String, dynamic>> getAiDashboard(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/ai/dashboard/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Не удалось получить данные AI'
      };
    } catch (e) {
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // ---------- AI: Scan ----------
  Future<Map<String, dynamic>> aiScan({
    required int userId,
    required String mimeType,
    required String base64Image,
    String? prompt,
  }) async {
    try {
      print('[AI Scan] Starting analysis for user $userId');
      final res = await http
          .post(
            Uri.parse('$_baseUrl/ai/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'mimeType': mimeType,
              'base64Image': base64Image,
              if (prompt != null && prompt.trim().isNotEmpty)
                'prompt': prompt.trim(),
            }),
          )
          .timeout(_longTimeout); // Используем длинный таймаут для AI
      print('[AI Scan] Response status: ${res.statusCode}');
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('[AI Scan] Success!');
        return {'success': true, 'data': body['data'], 'ai': body['ai']};
      }
      print('[AI Scan] Error: ${body['message']}');
      return {
        'success': false,
        'message': body['message'] ?? 'Ошибка анализа изображения',
        'ai': body['ai']
      };
    } catch (e) {
      print('[AI Scan] Exception: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // ---------- AI: Voice ----------
  Future<Map<String, dynamic>> aiVoice({
    required int userId,
    required String mimeType,
    required String base64Audio,
    String? prompt,
  }) async {
    try {
      print('[AI Voice] Starting transcription for user $userId');
      final res = await http
          .post(
            Uri.parse('$_baseUrl/ai/voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'mimeType': mimeType,
              'base64Audio': base64Audio,
              if (prompt != null && prompt.trim().isNotEmpty)
                'prompt': prompt.trim(),
            }),
          )
          .timeout(_longTimeout); // Используем длинный таймаут для AI
      print('[AI Voice] Response status: ${res.statusCode}');
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('[AI Voice] Success!');
        return {'success': true, 'data': body['data'], 'ai': body['ai']};
      }
      print('[AI Voice] Error: ${body['message']}');
      return {
        'success': false,
        'message': body['message'] ?? 'Ошибка обработки аудио',
        'ai': body['ai']
      };
    } catch (e) {
      print('[AI Voice] Exception: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // ---------- AI: Chat ----------
  Future<Map<String, dynamic>> aiChat({
    required int userId,
    required String message,
    required List<Map<String, dynamic>> history,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    try {
      print('[AI Chat] Sending message for user $userId');
      final res = await http
          .post(
            Uri.parse('$_baseUrl/ai/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'message': message,
              'history': history,
              if (attachments.isNotEmpty) 'attachments': attachments,
            }),
          )
          .timeout(
              _longTimeout); // Используем длинный таймаут для AI с вложениями
      print('[AI Chat] Response status: ${res.statusCode}');
      final body = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('[AI Chat] Success!');
        return {'success': true, 'data': body['data'], 'ai': body['ai']};
      }
      print('[AI Chat] Error: ${body['message']}');
      return {
        'success': false,
        'message': body['message'] ?? 'Ошибка чата',
        'ai': body['ai']
      };
    } catch (e) {
      print('[AI Chat] Exception: $e');
      return {'success': false, 'message': 'Ошибка подключения к серверу: $e'};
    }
  }

  // ========== Scan Notes Management ==========
  Future<Map<String, dynamic>> saveScanNote({
    required int userId,
    required String title,
    String? imageUrl,
    String? summary,
    List<String>? keyPoints,
    List<String>? questions,
    String? subject,
    List<String>? tags,
    List<Map<String, String>>? flashcards,
  }) async {
    try {
      // Используем новый эндпоинт /ai/scans/create для AI Notebook
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/scans/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'title': title,
              if (imageUrl != null) 'imageUrl': imageUrl,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              'concepts': [], // Добавляем пустые массивы для новой схемы
              'formulas': [],
              if (questions != null) 'questions': questions,
              if (subject != null) 'subject': subject,
              if (tags != null) 'tags': tags,
              'course': subject ?? '', // Используем subject как course
              'manualNotes': '',
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения конспекта: $e'};
    }
  }

  Future<Map<String, dynamic>> getScanNotes(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scans/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения конспектов: $e'};
    }
  }

  Future<Map<String, dynamic>> getScanNote(int userId, String scanId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scans/$userId/$scanId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения конспекта: $e'};
    }
  }

  Future<Map<String, dynamic>> updateScanNote({
    required int userId,
    required String scanId,
    String? title,
    String? summary,
    List<String>? keyPoints,
    List<String>? questions,
    String? subject,
    List<String>? tags,
    bool? favorite,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/scans/$userId/$scanId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (title != null) 'title': title,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              if (questions != null) 'questions': questions,
              if (subject != null) 'subject': subject,
              if (tags != null) 'tags': tags,
              if (favorite != null) 'favorite': favorite,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления конспекта: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteScanNote(int userId, String scanId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/scans/$userId/$scanId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления конспекта: $e'};
    }
  }

  // ========== Voice Recordings Management ==========
  Future<Map<String, dynamic>> saveVoiceRecording({
    required int userId,
    required String title,
    required String duration,
    String? audioPath,
    String? transcription,
    String? summary,
    List<String>? keyPoints,
    List<String>? tags,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recordings/save'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'title': title,
              'duration': duration,
              if (audioPath != null) 'audioPath': audioPath,
              if (transcription != null) 'transcription': transcription,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              if (tags != null) 'tags': tags,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения записи: $e'};
    }
  }

  Future<Map<String, dynamic>> getVoiceRecordings(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/recordings/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения записей: $e'};
    }
  }

  Future<Map<String, dynamic>> getVoiceRecording(
      int userId, String recordingId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/recordings/$userId/$recordingId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения записи: $e'};
    }
  }

  Future<Map<String, dynamic>> updateVoiceRecording({
    required int userId,
    required String recordingId,
    String? title,
    String? transcription,
    String? summary,
    List<String>? keyPoints,
    List<String>? tags,
    bool? favorite,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/recordings/$userId/$recordingId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (title != null) 'title': title,
              if (transcription != null) 'transcription': transcription,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              if (tags != null) 'tags': tags,
              if (favorite != null) 'favorite': favorite,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления записи: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteVoiceRecording(
      int userId, String recordingId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/recordings/$userId/$recordingId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления записи: $e'};
    }
  }

  // ========== QUIZ RESULTS API ==========

  Future<Map<String, dynamic>> saveQuizResult({
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/quiz-results'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'setId': setId,
              'setTitle': setTitle,
              'score': score,
              'totalQuestions': totalQuestions,
              'correctAnswers': correctAnswers,
              'durationSeconds': durationSeconds,
              'answers': answers,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения результата: $e'};
    }
  }

  Future<Map<String, dynamic>> getLatestQuizResult(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/quiz-results/latest/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения результата: $e'};
    }
  }

  Future<Map<String, dynamic>> getQuizHistory(int userId,
      {int limit = 20, int skip = 0}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/quiz-results/history/$userId?limit=$limit&skip=$skip'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения истории: $e'};
    }
  }

  // ========== ACHIEVEMENTS API ==========

  Future<Map<String, dynamic>> getAchievements(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/achievements/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения достижений: $e'};
    }
  }

  Future<Map<String, dynamic>> saveAchievement({
    required int userId,
    required String achievementId,
    required String type,
    required String name,
    String? description,
    String? icon,
    int? color,
    required bool isUnlocked,
    String? unlockedAt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/achievements'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'achievementId': achievementId,
          'type': type,
          'name': name,
          'description': description,
          'icon': icon,
          'color': color,
          'isUnlocked': isUnlocked,
          'unlockedAt': unlockedAt,
        }),
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения достижения: $e'};
    }
  }

  Future<Map<String, dynamic>> saveAchievementsBatch({
    required int userId,
    required List<Map<String, dynamic>> achievements,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/achievements/batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'achievements': achievements,
        }),
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка сохранения достижений: $e'};
    }
  }

  // ========== STATS API ==========

  Future<Map<String, dynamic>> reportActivity({
    required int userId,
    required String type,
    int? minutes,
  }) async {
    try {
      print(
          '[STATS] 🔥 Reporting activity: type=$type, minutes=$minutes, userId=$userId');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/stats/report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'type': type,
              if (minutes != null) 'minutes': minutes,
            }),
          )
          .timeout(_timeout);

      print('[STATS] Response status: ${response.statusCode}');
      print('[STATS] Response body: ${response.body}');

      final result = _handleResponse(response);
      print(
          '[STATS] Parsed result: success=${result['success']}, has streak=${result['streak'] != null}');

      // Обновляем streak в локальном хранилище если сервер вернул его
      if (result['success'] == true && result['streak'] != null) {
        final streakData = result['streak'] as Map<String, dynamic>;
        print(
            '[STATS] 🎉 Updating local streak: current=${streakData['current']}, longest=${streakData['longest']}');

        // Обновляем ai meta в UserPrefs
        final rawUser = await UserPrefs.getRawUser();
        if (rawUser != null) {
          final aiMeta = rawUser['ai'] as Map<String, dynamic>? ?? {};
          aiMeta['streak'] = streakData;
          await UserPrefs.updateAiMeta(aiMeta);
          print(
              '[STATS] ✅ Streak updated in UserPrefs, HeroSection should reload now');
        } else {
          print('[STATS] ⚠️ WARNING: rawUser is null!');
        }
      } else {
        print(
            '[STATS] ❌ WARNING: Server did not return streak data! Result: $result');
      }

      return result;
    } catch (e) {
      print('[STATS] ❌ Error reporting activity: $e');
      return {'success': false, 'message': 'Ошибка отправки активности: $e'};
    }
  }

  Future<Map<String, dynamic>> getTodayStats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/today/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения статистики: $e'};
    }
  }

  Future<Map<String, dynamic>> getWeekStats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/week/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка получения недельной статистики: $e'
      };
    }
  }

  Future<Map<String, dynamic>> getMonthStats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/month/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка получения месячной статистики: $e'
      };
    }
  }

  Future<Map<String, dynamic>> clearAllStats(int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/stats/clear/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Ошибка очистки статистики: $e'
      };
    }
  }

  // ========== NOTEBOOK API ==========

  Future<Map<String, dynamic>> getNotebookEntries(
    int userId, {
    String? type,
    List<String>? tags,
    String? course,
    String? search,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };
      if (type != null) queryParams['type'] = type;
      if (course != null) queryParams['course'] = course;
      if (search != null) queryParams['search'] = search;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');

      final uri = Uri.parse('$_baseUrl/notebook/$userId')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения записей: $e'};
    }
  }

  Future<Map<String, dynamic>> getNotebookEntry(
      int userId, String entryId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notebook/$userId/$entryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения записи: $e'};
    }
  }

  Future<Map<String, dynamic>> createNotebookEntry({
    required int userId,
    required String type,
    required String title,
    String? summary,
    List<String>? tags,
    String? course,
    String? linkedResourceId,
    String? manualNotes,
    int? color,
    int? icon,
    String? priority,
    DateTime? reminderDate,
    List? checklistItems,
    List<String>? attachments,
    bool? isPinned,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'title': title,
      };
      if (summary != null) body['summary'] = summary;
      if (tags != null) body['tags'] = tags;
      if (course != null) body['course'] = course;
      if (linkedResourceId != null) body['linkedResourceId'] = linkedResourceId;
      if (manualNotes != null) body['manualNotes'] = manualNotes;
      if (color != null) body['color'] = color;
      if (icon != null) body['icon'] = icon;
      if (priority != null) body['priority'] = priority;
      if (reminderDate != null)
        body['reminderDate'] = reminderDate.toIso8601String();
      if (checklistItems != null) body['checklistItems'] = checklistItems;
      if (attachments != null) body['attachments'] = attachments;
      if (isPinned != null) body['isPinned'] = isPinned;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/notebook/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка создания записи: $e'};
    }
  }

  Future<Map<String, dynamic>> updateNotebookEntry({
    required int userId,
    required String entryId,
    String? title,
    String? summary,
    List<String>? tags,
    String? course,
    String? manualNotes,
    int? color,
    int? icon,
    String? priority,
    DateTime? reminderDate,
    List? checklistItems,
    List<String>? attachments,
    bool? isPinned,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (summary != null) body['summary'] = summary;
      if (tags != null) body['tags'] = tags;
      if (course != null) body['course'] = course;
      if (manualNotes != null) body['manualNotes'] = manualNotes;
      if (color != null) body['color'] = color;
      if (icon != null) body['icon'] = icon;
      if (priority != null) body['priority'] = priority;
      if (reminderDate != null)
        body['reminderDate'] = reminderDate.toIso8601String();
      if (checklistItems != null) body['checklistItems'] = checklistItems;
      if (attachments != null) body['attachments'] = attachments;
      if (isPinned != null) body['isPinned'] = isPinned;

      final response = await http
          .put(
            Uri.parse('$_baseUrl/notebook/$userId/$entryId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления записи: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteNotebookEntry(
      int userId, String entryId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/notebook/$userId/$entryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления записи: $e'};
    }
  }

  // ========== PLANNER API ==========

  Future<Map<String, dynamic>> getWeekPlanner(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/planner/week/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения плана: $e'};
    }
  }

  Future<Map<String, dynamic>> updateWeekPlanner(
      int userId, List<Map<String, dynamic>> tasks) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/planner/week/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'tasks': tasks}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка обновления плана: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleTask(String taskId, int userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/planner/task/$taskId/toggle'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка переключения задачи: $e'};
    }
  }

  Future<Map<String, dynamic>> generatePlanner(int userId,
      {DateTime? targetDate}) async {
    try {
      final body = targetDate != null
          ? jsonEncode({'targetDate': targetDate.toIso8601String()})
          : null;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/planner/generate/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации плана: $e'};
    }
  }

  Future<Map<String, dynamic>> addPlannerTask({
    required int userId,
    required DateTime date,
    required String title,
    String type = 'custom',
    String priority = 'medium',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/planner/task/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'date': date.toIso8601String(),
              'title': title,
              'type': type,
              'priority': priority,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка добавления задачи: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePlannerTask(
      String taskId, int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/planner/task/$userId/$taskId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка удаления задачи: $e'};
    }
  }

  // ========== INSIGHTS API ==========

  Future<Map<String, dynamic>> getWeekInsights(int userId,
      {String? weekStart}) async {
    try {
      final uri = Uri.parse('$_baseUrl/insights/week/$userId').replace(
        queryParameters: weekStart != null ? {'weekStart': weekStart} : null,
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения инсайтов: $e'};
    }
  }

  Future<Map<String, dynamic>> getLatestInsights(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/insights/latest/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка получения инсайтов: $e'};
    }
  }

  Future<Map<String, dynamic>> generateInsights(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/insights/generate/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации инсайтов: $e'};
    }
  }

  // ========== AI EXTENDED RESOURCES API ==========

  Future<Map<String, dynamic>> createAiLecture({
    required int userId,
    String? recordingId,
    required String title,
    int? durationSeconds,
    String? transcription,
    String? summary,
    List<String>? keyPoints,
    List<String>? keyConcepts,
    List<String>? questions,
    List<String>? tags,
    String? course,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/lectures/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              if (recordingId != null) 'recordingId': recordingId,
              'title': title,
              if (durationSeconds != null) 'durationSeconds': durationSeconds,
              if (transcription != null) 'transcription': transcription,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              if (keyConcepts != null) 'keyConcepts': keyConcepts,
              if (questions != null) 'questions': questions,
              if (tags != null) 'tags': tags,
              if (course != null) 'course': course,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка создания лекции: $e'};
    }
  }

  Future<Map<String, dynamic>> createAiScanNote({
    required int userId,
    required String title,
    String? imageUrl,
    String? summary,
    List<String>? keyPoints,
    List<String>? concepts,
    List<String>? formulas,
    List<String>? questions,
    String? subject,
    List<String>? tags,
    String? course,
    String? manualNotes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/scans/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'title': title,
              if (imageUrl != null) 'imageUrl': imageUrl,
              if (summary != null) 'summary': summary,
              if (keyPoints != null) 'keyPoints': keyPoints,
              if (concepts != null) 'concepts': concepts,
              if (formulas != null) 'formulas': formulas,
              if (questions != null) 'questions': questions,
              if (subject != null) 'subject': subject,
              if (tags != null) 'tags': tags,
              if (course != null) 'course': course,
              if (manualNotes != null) 'manualNotes': manualNotes,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка создания конспекта: $e'};
    }
  }

  Future<Map<String, dynamic>> createAiSession({
    required int userId,
    String? title,
    List<String>? goals,
    List<String>? keyTakeaways,
    List<String>? homework,
    List<String>? suggestedNextSteps,
    int? messagesCount,
    int? durationMinutes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/sessions/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              if (title != null) 'title': title,
              if (goals != null) 'goals': goals,
              if (keyTakeaways != null) 'keyTakeaways': keyTakeaways,
              if (homework != null) 'homework': homework,
              if (suggestedNextSteps != null)
                'suggestedNextSteps': suggestedNextSteps,
              if (messagesCount != null) 'messagesCount': messagesCount,
              if (durationMinutes != null) 'durationMinutes': durationMinutes,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка создания сессии: $e'};
    }
  }

  Future<Map<String, dynamic>> generateCardsFromLecture(
      String lectureId, int userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/lectures/$lectureId/cards'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации карточек: $e'};
    }
  }

  Future<Map<String, dynamic>> generateCardsFromScan(
      String scanId, int userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/scans/$scanId/cards'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации карточек: $e'};
    }
  }

  Future<Map<String, dynamic>> generateCardsFromMetadata({
    required int userId,
    required String title,
    String? course,
    List<String>? tags,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/generate-cards-from-metadata'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'title': title,
              'course': course,
              'tags': tags ?? [],
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Ошибка генерации карточек: $e'};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': body};
    } else {
      return {
        'success': false,
        'message': body['message'] ?? 'An error occurred'
      };
    }
  }
}
