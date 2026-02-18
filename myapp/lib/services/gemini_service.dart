import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class GeminiService {
  // Now uses server proxy to keep keys off-device

  Future<Map<String, dynamic>> analyzeImage(dynamic imageInput, [String? mimeType]) async {
    String base64Image;
    String contentType;
    
    if (imageInput is File) {
      // Convert File to base64
      final bytes = await imageInput.readAsBytes();
      base64Image = base64Encode(bytes);
      
      // Determine MIME type from file extension
      final extension = imageInput.path.split('.').last.toLowerCase();
      contentType = mimeType ?? _getMimeType(extension);
    } else if (imageInput is String) {
      // Already base64 encoded
      base64Image = imageInput;
      contentType = mimeType ?? 'image/jpeg';
    } else {
      throw ArgumentError('imageInput must be either File or String (base64)');
    }
    
    return _analyzeImageBase64(base64Image, contentType);
  }
  
  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
  
  Future<Map<String, dynamic>> _analyzeImageBase64(String base64Image, String mimeType) async {
    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text': 'Проанализируй этот конспект. Предоставь краткую сводку (не более 150 слов), '
                  'ключевые моменты (3-5 пунктов) и возможные вопросы для теста (3-5 вопросов). '
                  'Ответь на русском языке.'
            },
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/analyze-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mimeType': mimeType,
          'base64Image': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'summary': result['summary'] ?? '',
          'keyPoints': List<String>.from(result['keyPoints'] ?? const []),
          'questions': List<String>.from(result['questions'] ?? const []),
        };
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error: $e');
      // Return error-aware fallback if API fails
      return _getErrorFallback('анализа изображения', e.toString());
    }
  }

  Future<Map<String, dynamic>> analyzeAudioTranscription(String transcription) async {
    final payload = {
      'contents': [
        {
          'parts': [
            {
              'text': 'Проанализируй эту расшифровку лекции: "$transcription". '
                  'Предоставь краткую сводку (не более 150 слов), '
                  'ключевые моменты (3-5 пунктов) и возможные вопросы для теста (3-5 вопросов). '
                  'Ответь на русском языке.'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/analyze-text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transcription': transcription,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'summary': result['summary'] ?? '',
          'keyPoints': List<String>.from(result['keyPoints'] ?? const []),
          'questions': List<String>.from(result['questions'] ?? const []),
        };
      } else {
        throw Exception('Failed to analyze transcription: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error: $e');
      return _getErrorFallback('анализа расшифровки', e.toString());
    }
  }

  Future<String> getChatResponse(String message, List<Map<String, String>> history) async {
    final messages = history.map((msg) => {
      'parts': [{'text': msg['text']}],
      'role': msg['sender'] == 'user' ? 'user' : 'model'
    }).toList();

    messages.add({
      'parts': [{'text': message}],
      'role': 'user'
    });

    final payload = {
      'contents': messages,
      'generationConfig': {
        'temperature': 0.9,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      },
      'systemInstruction': {
        'parts': [{
          'text': 'Ты - AI-репетитор StudyMate. Помогай студентам с учебой, '
              'отвечай на вопросы, объясняй сложные концепции простым языком. '
              'Будь дружелюбным и поддерживающим. Отвечай на русском языке.'
        }]
      }
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['text'] ?? '...';
      } else {
        throw Exception('Failed to get chat response: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error: $e');
      return 'Извините, произошла ошибка при обработке вашего запроса. Попробуйте еще раз.';
    }
  }

  /// Генерировать персональную обратную связь после квиза
  Future<String> generatePersonalizedFeedback({
    required String topic,
    required List<Map<String, dynamic>> wrongAnswers, // [{question, userAnswer, correctAnswer}]
    required int level,
    required double score,
    required int userId,
  }) async {
    try {
      final wrongAnswersText = wrongAnswers.map((a) => 
        'Вопрос: ${a['question']}\nТвой ответ: ${a['userAnswer']}\nПравильный ответ: ${a['correctAnswer']}'
      ).join('\n\n');

      String prompt;
      if (wrongAnswers.isEmpty) {
        // Если все правильно - ободряющая сводка
        prompt = 'Ты - AI-наставник для студента. Студент прошел квиз по теме "$topic" '
            'на уровне $level и ответил правильно на ВСЕ вопросы (${(score * 100).round()}% правильных ответов).\n\n'
            'Дай короткую ободряющую сводку на русском языке. Похвали студента за отличный результат и предложи следующие шаги для продолжения обучения. '
            'Ответ должен быть кратким и мотивирующим (не более 150 слов).';
      } else {
        // Если есть ошибки - анализ ошибок
        prompt = 'Ты - AI-наставник для студента. Студент прошел квиз по теме "$topic" '
            'на уровне $level и получил ${(score * 100).round()}% правильных ответов.\n\n'
            'Неправильные ответы:\n$wrongAnswersText\n\n'
            'Дай персональную обратную связь на русском языке. Объясни, почему студент ошибся в каждом случае, '
            'и дай конкретные советы для улучшения. Будь поддерживающим и конструктивным. '
            'Ответ должен быть кратким (не более 300 слов).';
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'message': prompt,
          'history': [],
          'skipChatTracking': true, // Не считать генерацию обратной связи как чат
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? {};
        final text = (data['text'] ?? result['text'] ?? '').toString().trim();
        return text.isNotEmpty ? text : 'Хорошая работа! Продолжай учиться.';
      } else {
        throw Exception('Failed to get feedback: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error (feedback): $e');
      return 'Отличная работа! Продолжай тренироваться и обращай внимание на те карточки, где ты ошибся.';
    }
  }

  /// Генерировать дистракторы (неправильные варианты ответов) для Kahoot-режима
  Future<List<String>> generateDistractors({
    required String correctAnswer,
    required String topic,
    required String question,
    required int userId,
  }) async {
    try {
      final prompt = 'Для квиза по теме "$topic" создай 3 неправильных варианта ответа (дистрактора). '
          'Вопрос: "$question"\nПравильный ответ: "$correctAnswer"\n\n'
          'Требования:\n'
          '- Дистракторы должны быть правдоподобными, но неправильными\n'
          '- Они должны быть связаны с темой\n'
          '- Каждый дистрактор должен быть коротким (1-2 предложения или фраза)\n'
          '- Верни ТОЛЬКО 3 варианта, каждый с новой строки\n'
          '- Не нумеруй и не используй маркеры, только текст вариантов\n'
          '- Пример формата:\n'
          'Вариант 1\n'
          'Вариант 2\n'
          'Вариант 3\n';

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'message': prompt,
          'history': [],
          'skipChatTracking': true, // Не считать генерацию дистракторов как чат
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? {};
        final text = (data['text'] ?? result['text'] ?? '').toString().trim();
        
        if (text.isEmpty) {
          throw Exception('Empty response from AI');
        }
        
        // Разбить на строки и очистить
        final lines = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        
        // Убрать маркеры и номера
        final distractors = lines
            .map((s) => s.replaceFirst(RegExp(r'^[\d\-\•\*\.\)]+[\s]+'), '').trim())
            .where((s) => s.isNotEmpty && s.length > 3)
            .take(3)
            .toList();
        
        // Если получили меньше 3, добавить fallback
        while (distractors.length < 3) {
          distractors.add('Альтернативный вариант ${distractors.length + 1}');
        }
        
        return distractors;
      } else {
        throw Exception('Failed to get distractors: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error (distractors): $e');
      // Fallback
      return [
        'Альтернативный вариант 1',
        'Альтернативный вариант 2',
        'Альтернативный вариант 3',
      ];
    }
  }

  /// Генерировать анализ ошибок для Kahoot-режима
  Future<String> generateErrorAnalysis({
    required String topic,
    required List<Map<String, dynamic>> wrongAnswers,
    required int totalQuestions,
    required int correctAnswers,
    required int userId,
  }) async {
    try {
      String prompt;
      if (wrongAnswers.isEmpty) {
        // Если все правильно - ободряющая сводка
        prompt = 'Ты - AI-наставник. Студент прошел Kahoot-квиз по теме "$topic" '
            'и ответил правильно на ВСЕ вопросы ($correctAnswers из $totalQuestions).\n\n'
            'Дай короткую ободряющую сводку на русском языке. Похвали за отличный результат и предложи следующие шаги. '
            'Ответ должен быть кратким и мотивирующим (не более 150 слов).';
      } else {
        // Если есть ошибки - анализ ошибок
        final wrongAnswersText = wrongAnswers.map((a) => 
          'Вопрос: ${a['question']}\nТвой ответ: ${a['userAnswer']}\nПравильный ответ: ${a['correctAnswer']}'
        ).join('\n\n');
        
        prompt = 'Ты - AI-наставник. Студент прошел Kahoot-квиз по теме "$topic" '
            'и ответил правильно на $correctAnswers из $totalQuestions вопросов.\n\n'
            'Неправильные ответы:\n$wrongAnswersText\n\n'
            'Проанализируй ошибки и дай работу над ошибками на русском языке. '
            'Объясни, почему студент ошибся, и дай конкретные советы для улучшения. '
            'Ответ должен быть кратким и конструктивным (не более 250 слов).';
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'message': prompt,
          'history': [],
          'skipChatTracking': true, // Не считать генерацию дистракторов как чат
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? {};
        final text = (data['text'] ?? result['text'] ?? '').toString().trim();
        return text.isNotEmpty ? text : 'Продолжай тренироваться!';
      } else {
        throw Exception('Failed to get error analysis: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemini API Error (error analysis): $e');
      return 'Отличная работа! Продолжай учиться и обращай внимание на те вопросы, где ты ошибся.';
    }
  }

  Map<String, dynamic> _parseAnalysisResponse(String response) {
    // Simple parsing - in production, use more sophisticated parsing
    final lines = response.split('\n');
    String summary = '';
    List<String> keyPoints = [];
    List<String> questions = [];

    String currentSection = '';
    for (final line in lines) {
      if (line.toLowerCase().contains('сводка') || line.toLowerCase().contains('summary')) {
        currentSection = 'summary';
      } else if (line.toLowerCase().contains('ключевые') || line.toLowerCase().contains('key points')) {
        currentSection = 'keyPoints';
      } else if (line.toLowerCase().contains('вопрос') || line.toLowerCase().contains('question')) {
        currentSection = 'questions';
      } else if (line.trim().isNotEmpty) {
        switch (currentSection) {
          case 'summary':
            summary += line + ' ';
            break;
          case 'keyPoints':
            if (line.trim().startsWith('-') || line.trim().startsWith('•') || line.trim().startsWith('*')) {
              keyPoints.add(line.trim().substring(1).trim());
            } else if (line.trim().length > 10) {
              keyPoints.add(line.trim());
            }
            break;
          case 'questions':
            if (line.trim().startsWith('-') || line.trim().startsWith('•') || line.trim().startsWith('*')) {
              questions.add(line.trim().substring(1).trim());
            } else if (line.trim().length > 10) {
              questions.add(line.trim());
            }
            break;
        }
      }
    }

    // If parsing failed, try to extract from the whole response
    if (summary.isEmpty && keyPoints.isEmpty && questions.isEmpty) {
      summary = response.length > 200 ? response.substring(0, 200) + '...' : response;
      keyPoints = ['Анализ документа выполнен', 'Информация обработана', 'Готово к изучению'];
      questions = ['Что является основной темой материала?', 'Какие ключевые концепции представлены?'];
    }

    return {
      'summary': summary.trim(),
      'keyPoints': keyPoints.take(5).toList(),
      'questions': questions.take(5).toList(),
    };
  }

  Map<String, dynamic> _getErrorFallback(String operationType, String errorDetails) {
    // Generate a more informative fallback based on error type
    String summaryMessage;
    List<String> keyPoints;
    List<String> questions;

    if (errorDetails.contains('Connection') || errorDetails.contains('Failed host lookup')) {
      summaryMessage = '⚠️ Не удалось подключиться к серверу AI-анализа. '
          'Проверьте подключение к интернету и настройки сервера. '
          'Материал загружен, но автоматический анализ недоступен.';
      keyPoints = [
        'Анализ временно недоступен из-за проблем с подключением',
        'Вы можете создать карточки вручную',
        'Попробуйте снова позже, когда соединение восстановится',
      ];
      questions = [
        'Проверьте настройки сервера в конфигурации',
        'Убедитесь, что интернет-соединение стабильно',
      ];
    } else if (errorDetails.contains('401') || errorDetails.contains('403')) {
      summaryMessage = '🔒 Ошибка авторизации AI-сервиса. '
          'Проверьте настройки API-ключа на сервере. '
          'Материал сохранён, но автоматический анализ требует настройки.';
      keyPoints = [
        'Требуется настройка API-ключа на сервере',
        'Обратитесь к администратору для настройки',
        'Вы можете создавать карточки вручную',
      ];
      questions = [
        'Настроен ли API-ключ Gemini на сервере?',
        'Проверьте переменные окружения сервера',
      ];
    } else if (errorDetails.contains('429')) {
      summaryMessage = '⏱️ Превышен лимит запросов к AI-сервису. '
          'Пожалуйста, подождите немного и попробуйте снова. '
          'Материал сохранён для последующей обработки.';
      keyPoints = [
        'Достигнут лимит запросов к AI',
        'Попробуйте через несколько минут',
        'Можно создать карточки вручную прямо сейчас',
      ];
      questions = [
        'Сколько запросов осталось на сегодня?',
        'Рассмотрите возможность обновления лимитов API',
      ];
    } else {
      summaryMessage = '⚠️ Произошла ошибка при обработке материала AI-сервисом. '
          'Материал сохранён. Вы можете создать учебные карточки вручную '
          'или попробовать загрузить материал повторно.';
      keyPoints = [
        'AI-анализ временно недоступен',
        'Материал успешно загружен и сохранён',
        'Создайте карточки вручную или повторите попытку позже',
        'Проверьте формат и качество изображения',
      ];
      questions = [
        'Достаточно ли чёткое изображение для анализа?',
        'Не слишком ли большой размер файла?',
        'Попробуйте улучшить освещение или качество фото',
      ];
    }

    return {
      'summary': summaryMessage,
      'keyPoints': keyPoints,
      'questions': questions,
      '_error': true, // Flag to indicate this is an error fallback
      '_errorType': operationType,
      '_errorDetails': errorDetails,
    };
  }
}
