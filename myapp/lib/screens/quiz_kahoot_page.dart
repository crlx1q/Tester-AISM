import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/study_set.dart';
import '../models/quiz_result.dart';
import '../services/profile_notifier.dart';
import '../services/gemini_service.dart';
import '../providers/quiz_provider.dart';
import 'quiz_summary_page.dart';

class QuizKahootPage extends StatefulWidget {
  final StudySet studySet;

  const QuizKahootPage({
    Key? key,
    required this.studySet,
  }) : super(key: key);

  @override
  State<QuizKahootPage> createState() => _QuizKahootPageState();
}

class _QuizKahootPageState extends State<QuizKahootPage> {
  int _currentCardIndex = 0;
  int _timeRemaining = 15; // 15 секунд на вопрос
  Timer? _timer;
  bool _hasAnswered = false;
  int? _selectedAnswerIndex;
  List<QuizAnswer> _answers = [];
  DateTime _quizStartTime = DateTime.now();
  DateTime _questionStartTime = DateTime.now();
  
  // Kahoot mode: 4 варианта ответа для каждого вопроса
  List<List<String>> _answerOptions = []; // [правильный, дистрактор1, дистрактор2, дистрактор3]
  List<int> _correctIndices = []; // Индекс правильного ответа для каждого вопроса
  
  final GeminiService _geminiService = GeminiService();
  bool _isGeneratingOptions = false;
  String? _aiErrorAnalysis;

  @override
  void initState() {
    super.initState();
    _quizStartTime = DateTime.now();
    _questionStartTime = DateTime.now();
    // Небольшая задержка перед генерацией для отображения UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAnswerOptions();
    });
  }
  
  int _generatedOptionsCount = 0; // Для прогресс бара

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generateAnswerOptions() async {
    setState(() => _isGeneratingOptions = true);
    
    try {
      final allOptions = <List<String>>[];
      final correctIndices = <int>[];
      
      // Kahoot: максимум 10 карточек
      final cardsToUse = widget.studySet.cards.length > 10
          ? widget.studySet.cards.take(10).toList()
          : widget.studySet.cards;
      
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) {
        setState(() => _isGeneratingOptions = false);
        return;
      }
      
      // Генерируем варианты для каждой карточки
      for (var i = 0; i < cardsToUse.length; i++) {
        final card = cardsToUse[i];
        try {
          // Обновляем прогресс
          if (mounted) {
            setState(() {
              _generatedOptionsCount = i;
            });
          }
          
          // Генерируем дистракторы через ИИ
          final distractors = await _geminiService.generateDistractors(
            correctAnswer: card.definition,
            topic: widget.studySet.title,
            question: card.term,
            userId: user.id,
          );
          
          // Создаем список из 4 вариантов (правильный + 3 дистрактора)
          final options = [card.definition, ...distractors];
          options.shuffle(); // Перемешиваем
          
          final correctIndex = options.indexOf(card.definition);
          allOptions.add(options);
          correctIndices.add(correctIndex);
        } catch (e) {
          print('[Kahoot] Error generating options for card: $e');
          // Fallback: простые варианты
          final options = [
            card.definition,
            'Вариант 1',
            'Вариант 2',
            'Вариант 3',
          ];
          options.shuffle();
          final correctIndex = options.indexOf(card.definition);
          allOptions.add(options);
          correctIndices.add(correctIndex);
        }
      }
      
      setState(() {
        _answerOptions = allOptions;
        _correctIndices = correctIndices;
        _isGeneratingOptions = false;
      });
      
      _startTimer();
    } catch (e) {
      print('[Kahoot] Error generating options: $e');
      setState(() => _isGeneratingOptions = false);
      // Fallback на простые варианты
      _generateFallbackOptions();
    }
  }

  void _generateFallbackOptions() {
    final allOptions = <List<String>>[];
    final correctIndices = <int>[];
    
    // Kahoot: максимум 10 карточек
    final cardsToUse = widget.studySet.cards.length > 10
        ? widget.studySet.cards.take(10).toList()
        : widget.studySet.cards;
    
    for (var card in cardsToUse) {
      final options = [
        card.definition,
        'Неверный вариант 1',
        'Неверный вариант 2',
        'Неверный вариант 3',
      ];
      options.shuffle();
      final correctIndex = options.indexOf(card.definition);
      allOptions.add(options);
      correctIndices.add(correctIndex);
    }
    
    setState(() {
      _answerOptions = allOptions;
      _correctIndices = correctIndices;
    });
    
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeRemaining = 15;
    _hasAnswered = false;
    _selectedAnswerIndex = null;
    _questionStartTime = DateTime.now();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_timeRemaining > 0 && !_hasAnswered) {
        setState(() {
          _timeRemaining--;
        });
      } else if (_timeRemaining == 0 && !_hasAnswered) {
        // Время вышло - автоматически выбираем как неправильный ответ
        _selectAnswer(null, isTimeout: true);
      }
    });
  }

  void _selectAnswer(int? index, {bool isTimeout = false}) {
    if (_hasAnswered || _isGeneratingOptions) return;
    
    _timer?.cancel();
    setState(() {
      _hasAnswered = true;
      _selectedAnswerIndex = index;
    });
    
    final currentCard = widget.studySet.cards[_currentCardIndex];
    final isCorrect = index != null && index == _correctIndices[_currentCardIndex];
    final timeSpent = DateTime.now().difference(_questionStartTime).inSeconds;
    
    _answers.add(QuizAnswer(
      question: currentCard.term,
      correctAnswer: currentCard.definition,
      userAnswer: index != null 
          ? _answerOptions[_currentCardIndex][index]
          : (isTimeout ? 'Время вышло' : ''),
      isCorrect: isCorrect,
      timeSpent: timeSpent,
    ));
    
    // Через 2 секунды переходим к следующему вопросу
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    final totalCards = widget.studySet.cards.length > 10
        ? 10
        : widget.studySet.cards.length;
        
    if (_currentCardIndex < totalCards - 1) {
      setState(() {
        _currentCardIndex++;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final totalDuration = DateTime.now().difference(_quizStartTime).inSeconds;
    final correctCount = _answers.where((a) => a.isCorrect).length;
    final totalQuestions = widget.studySet.cards.length > 10
        ? 10
        : widget.studySet.cards.length;
    final scorePercent = ((correctCount / totalQuestions) * 100).round();

    // Получить ИИ-анализ ошибок
    final wrongAnswers = _answers
        .where((a) => !a.isCorrect)
        .map((a) => {
          'question': a.question,
          'userAnswer': a.userAnswer,
          'correctAnswer': a.correctAnswer,
        })
        .toList();

    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    
    if (user != null) {
      try {
        // Генерируем анализ ошибок (сводку) даже если все правильно
        _aiErrorAnalysis = await _geminiService.generateErrorAnalysis(
          topic: widget.studySet.title,
          wrongAnswers: wrongAnswers,
          totalQuestions: totalQuestions,
          correctAnswers: correctCount,
          userId: user.id,
        );
      } catch (e) {
        print('[Kahoot] Error generating AI analysis: $e');
        _aiErrorAnalysis = 'Отличная работа! Ты ответил правильно на $correctCount из $totalQuestions вопросов.';
      }
    }

    if (user != null && mounted) {
      // Сохранить результат через Provider
      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      await quizProvider.saveResult(
        userId: user.id,
        setId: widget.studySet.id,
        setTitle: widget.studySet.title,
        score: scorePercent,
        totalQuestions: totalQuestions,
        correctAnswers: correctCount,
        durationSeconds: totalDuration,
        answers: _answers.map((a) => a.toJson()).toList(),
      );
      
      final quizResult = QuizResult(
        id: '',
        userId: user.id,
        setId: widget.studySet.id,
        setTitle: widget.studySet.title,
        score: scorePercent,
        totalQuestions: totalQuestions,
        correctAnswers: correctCount,
        durationSeconds: totalDuration,
        answers: _answers,
        createdAt: DateTime.now(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizSummaryPage(
            result: quizResult,
            studySet: widget.studySet,
            aiFeedback: _aiErrorAnalysis,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_isGeneratingOptions) {
      final totalCards = widget.studySet.cards.length > 10 ? 10 : widget.studySet.cards.length;
      final progress = totalCards > 0 ? _generatedOptionsCount / totalCards : 0.0;
      
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Подготовка квиза',
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              const SizedBox(height: 24),
              Text(
                'Генерируем варианты ответов...\n$_generatedOptionsCount из $totalCards',
                style: TextStyle(color: subtextColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_answerOptions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Text(
            'Ошибка подготовки квиза',
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }

    final totalCards = widget.studySet.cards.length > 10
        ? 10
        : widget.studySet.cards.length;
    final cardsToUse = widget.studySet.cards.length > 10
        ? widget.studySet.cards.take(10).toList()
        : widget.studySet.cards;
        
    final currentCard = cardsToUse[_currentCardIndex];
    final options = _answerOptions[_currentCardIndex];
    final correctIndex = _correctIndices[_currentCardIndex];
    final progress = (_currentCardIndex + 1) / totalCards;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.studySet.title,
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          
          // Timer and question counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _timeRemaining <= 5 
                        ? Colors.red.withOpacity(0.2)
                        : const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        color: _timeRemaining <= 5 ? Colors.red : const Color(0xFF6366F1),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_timeRemaining сек',
                        style: TextStyle(
                          color: _timeRemaining <= 5 ? Colors.red : const Color(0xFF6366F1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Question counter
                Text(
                  '${_currentCardIndex + 1} / ${widget.studySet.cards.length > 10 ? 10 : widget.studySet.cards.length}',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Text(
                      currentCard.term,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Answer options
                  ...options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedAnswerIndex == index;
                    final isCorrectAnswer = index == correctIndex;
                    final showResult = _hasAnswered;
                    
                    Color backgroundColor;
                    Color borderColor;
                    Color textColorOption;
                    
                    if (showResult) {
                      if (isSelected && isCorrectAnswer) {
                        // Правильный ответ
                        backgroundColor = Colors.green.withOpacity(0.2);
                        borderColor = Colors.green;
                        textColorOption = Colors.green;
                      } else if (isSelected && !isCorrectAnswer) {
                        // Неправильный ответ
                        backgroundColor = Colors.red.withOpacity(0.2);
                        borderColor = Colors.red;
                        textColorOption = Colors.red;
                      } else if (!isSelected && isCorrectAnswer) {
                        // Правильный ответ, но не выбран
                        backgroundColor = Colors.green.withOpacity(0.1);
                        borderColor = Colors.green.withOpacity(0.5);
                        textColorOption = Colors.green;
                      } else {
                        // Обычный вариант
                        backgroundColor = cardColor;
                        borderColor = Colors.grey.withOpacity(0.3);
                        textColorOption = textColor;
                      }
                    } else {
                      // До ответа
                      backgroundColor = cardColor;
                      borderColor = isSelected 
                          ? const Color(0xFF6366F1)
                          : Colors.grey.withOpacity(0.3);
                      textColorOption = textColor;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: showResult ? null : () => _selectAnswer(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: borderColor,
                                width: 2,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: borderColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : null,
                            ),
                            child: Row(
                              children: [
                                // Option letter (A, B, C, D)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: borderColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D
                                      style: TextStyle(
                                        color: borderColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: textColorOption,
                                      fontSize: 18,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (showResult && isCorrectAnswer)
                                  const Icon(
                                    LucideIcons.checkCircle2,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                if (showResult && isSelected && !isCorrectAnswer)
                                  const Icon(
                                    LucideIcons.xCircle,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
