import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/study_set.dart';
import '../models/quiz_result.dart';
import '../models/quiz_level.dart';
import '../services/study_sets_service.dart';
import '../services/profile_notifier.dart';
import '../services/quiz_adaptation_service.dart';
import '../services/gemini_service.dart';
import '../services/achievements_service.dart';
import '../providers/quiz_provider.dart';
import 'quiz_summary_page.dart';
import 'quiz_mode_selection_page.dart';

class QuizPage extends StatefulWidget {
  final String? setId;
  final QuizMode? mode; // Режим квиза (memory или training)
  
  const QuizPage({Key? key, this.setId, this.mode}) : super(key: key);

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<StudySet> _studySets = [];
  StudySet? _selectedSet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    try {
      final sets = await StudySetsService().getStudySets();
      setState(() {
        _studySets = sets;
        _isLoading = false;
        
        if (widget.setId != null) {
          _selectedSet = sets.firstWhere(
            (set) => set.id == widget.setId,
            orElse: () => sets.first,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (_selectedSet != null) {
      // Если режим не указан, показываем выбор режима
      if (widget.mode == null) {
        return QuizModeSelectionPage(
          studySet: _selectedSet!,
        );
      }
      
      return QuizPlayScreen(
        studySet: _selectedSet!,
        mode: widget.mode ?? QuizMode.memory,
        onBack: () {
          setState(() {
            _selectedSet = null;
          });
        },
      );
    }

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
          'Начать квиз',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _studySets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.fileQuestion,
                    color: subtextColor,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Сначала создайте учебный набор',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _studySets.length,
              itemBuilder: (context, index) {
                final set = _studySets[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.0 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedSet = set;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: set.color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                set.icon,
                                color: set.color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    set.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${set.cards.length} карточек',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              LucideIcons.playCircle,
                              color: const Color(0xFF6366F1),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Quiz play screen with flip cards
class QuizPlayScreen extends StatefulWidget {
  final StudySet studySet;
  final QuizMode mode;
  final VoidCallback onBack;

  const QuizPlayScreen({
    Key? key,
    required this.studySet,
    required this.mode,
    required this.onBack,
  }) : super(key: key);

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  final Set<int> _knownCards = {};
  final Set<int> _unknownCards = {};
  
  // Quiz timing tracking
  late DateTime _quizStartTime;
  late DateTime _questionStartTime;
  final List<QuizAnswer> _answers = [];
  
  // Training mode specific
  final QuizAdaptationService _adaptationService = QuizAdaptationService();
  final GeminiService _geminiService = GeminiService();
  final AchievementsService _achievementsService = AchievementsService();
  List<StudyCard> _adaptiveCards = [];
  QuizProgress? _currentProgress;
  int _currentLevel = 1;
  bool _isLoadingTrainingData = false;
  Map<String, int> _errorCounts = {};
  String? _aiFeedback;
  
  // Kahoot-style for training mode
  List<List<String>> _answerOptions = [];
  List<int> _correctIndices = [];
  int? _selectedAnswerIndex;
  bool _isGeneratingOptions = false;
  bool _hasAnswered = false;
  int _generatedOptionsCount = 0; // Для прогресс бара
  
  @override
  void initState() {
    super.initState();
    _quizStartTime = DateTime.now();
    _questionStartTime = DateTime.now();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.mode == QuizMode.training) {
      _initializeTrainingMode();
    }
  }
  
  Future<void> _initializeTrainingMode() async {
    setState(() => _isLoadingTrainingData = true);
    
    try {
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) return;
      
      final topic = widget.studySet.title;
      
      // Загрузить существующий прогресс
      _currentProgress = await _adaptationService.getProgress(user.id, topic);
      if (_currentProgress != null) {
        _currentLevel = _currentProgress!.currentLevel;
        _errorCounts = Map<String, int>.from(_currentProgress!.errorCounts);
        print('[Training] Loaded progress - Level: $_currentLevel, Mastery: ${_currentProgress!.masteryScore}');
      } else {
        // Если прогресс не найден, начинаем с уровня 1
        _currentLevel = 1;
        print('[Training] No existing progress, starting at level 1');
      }
      
      // Получить адаптивные вопросы
      _adaptiveCards = await _adaptationService.getAdaptiveQuestions(
        userId: user.id,
        topic: topic,
        level: _currentLevel,
        allCards: widget.studySet.cards,
        errorCounts: _errorCounts,
        count: 10,
      );
      
      // Для режима тренировки генерируем варианты ответов (Kahoot-стиль)
      await _generateTrainingOptions();
      
      setState(() => _isLoadingTrainingData = false);
    } catch (e) {
      print('[QuizPlayScreen] Error initializing training mode: $e');
      // Fallback to regular cards
      _adaptiveCards = List<StudyCard>.from(widget.studySet.cards);
      setState(() => _isLoadingTrainingData = false);
    }
  }
  
  List<StudyCard> get _currentCards {
    return widget.mode == QuizMode.training && _adaptiveCards.isNotEmpty
        ? _adaptiveCards
        : widget.studySet.cards;
  }
  
  Future<void> _generateTrainingOptions() async {
    if (widget.mode != QuizMode.training) return;
    
    setState(() => _isGeneratingOptions = true);
    
    try {
      final allOptions = <List<String>>[];
      final correctIndices = <int>[];
      
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) {
        setState(() => _isGeneratingOptions = false);
        return;
      }
      
      for (var i = 0; i < _adaptiveCards.length; i++) {
        final card = _adaptiveCards[i];
        try {
          // Обновляем прогресс
          setState(() {
            _generatedOptionsCount = i;
          });
          
          // Генерируем дистракторы через ИИ
          final distractors = await _geminiService.generateDistractors(
            correctAnswer: card.definition,
            topic: widget.studySet.title,
            question: card.term,
            userId: user.id,
          );
          
          // Создаем список из 4 вариантов
          final options = [card.definition, ...distractors];
          options.shuffle();
          
          final correctIndex = options.indexOf(card.definition);
          allOptions.add(options);
          correctIndices.add(correctIndex);
        } catch (e) {
          print('[Training] Error generating options: $e');
          // Fallback
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
        _generatedOptionsCount = _adaptiveCards.length;
      });
    } catch (e) {
      print('[Training] Error generating options: $e');
      setState(() => _isGeneratingOptions = false);
    }
  }
  
  void _selectTrainingAnswer(int index) {
    if (_hasAnswered || widget.mode != QuizMode.training) return;
    
    setState(() {
      _hasAnswered = true;
      _selectedAnswerIndex = index;
    });
    
    final currentCard = _currentCards[_currentCardIndex];
    final options = _answerOptions[_currentCardIndex];
    final isCorrect = index == _correctIndices[_currentCardIndex];
    final selectedAnswer = options[index];
    
    _recordAnswer(isCorrect: isCorrect, userAnswer: selectedAnswer);
    
    // Обновить счетчики ошибок
    if (!isCorrect) {
      _errorCounts[currentCard.term] = (_errorCounts[currentCard.term] ?? 0) + 1;
    }
    
    // Через 2 секунды переходим к следующему вопросу
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hasAnswered = false;
          _selectedAnswerIndex = null;
        });
        _questionStartTime = DateTime.now(); // Reset timer
        _nextCard();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_animationController.isAnimating) return;
    
    if (_isFlipped) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _markAsKnown() {
    _recordAnswer(isCorrect: true, userAnswer: null);
    setState(() {
      _knownCards.add(_currentCardIndex);
      _unknownCards.remove(_currentCardIndex);
    });
    _nextCard();
  }

  void _markAsUnknown() {
    _recordAnswer(isCorrect: false, userAnswer: null);
    setState(() {
      _unknownCards.add(_currentCardIndex);
      _knownCards.remove(_currentCardIndex);
    });
    _nextCard();
  }

  void _recordAnswer({required bool isCorrect, String? userAnswer}) {
    final currentCards = _currentCards;
    final currentCard = currentCards[_currentCardIndex];
    final timeSpent = DateTime.now().difference(_questionStartTime).inSeconds;
    
    // Обновить счетчики ошибок для режима тренировки
    if (widget.mode == QuizMode.training && !isCorrect) {
      _errorCounts[currentCard.term] = (_errorCounts[currentCard.term] ?? 0) + 1;
    }
    
    // Для режима тренировки сохраняем выбранный вариант, иначе определение
    final savedUserAnswer = userAnswer ?? (isCorrect ? currentCard.definition : '');
    
    _answers.add(QuizAnswer(
      question: currentCard.term,
      correctAnswer: currentCard.definition,
      userAnswer: savedUserAnswer,
      isCorrect: isCorrect,
      timeSpent: timeSpent,
    ));
  }

  void _nextCard() {
    final currentCards = _currentCards;
    if (_currentCardIndex < currentCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
        _questionStartTime = DateTime.now(); // Reset timer for new question
      });
      _animationController.reset();
    } else {
      // Quiz finished
      _finishQuiz();
    }
  }
  
  void _finishQuiz() async {
    final currentCards = _currentCards;
    final totalDuration = DateTime.now().difference(_quizStartTime).inSeconds;
    
    // Для режима тренировки считаем правильные ответы из _answers
    // Для режима памяти считаем из _knownCards
    final correctCount = widget.mode == QuizMode.training
        ? _answers.where((a) => a.isCorrect).length
        : _knownCards.length;
    final totalQuestions = currentCards.length;
    final scorePercent = totalQuestions > 0 
        ? ((correctCount / totalQuestions) * 100).round()
        : 0;

    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;

    if (user == null) return;

    // Для режима тренировки обновить прогресс и получить обратную связь
    if (widget.mode == QuizMode.training) {
      try {
        // Составить карту результатов для обновления прогресса
        final results = <String, bool>{};
        for (var answer in _answers) {
          results[answer.question] = answer.isCorrect;
        }
        
        // Обновить прогресс
        final updatedProgress = await _adaptationService.updateProgressAfterQuiz(
          userId: user.id,
          topic: widget.studySet.title,
          currentLevel: _currentLevel,
          correctAnswers: correctCount,
          totalQuestions: totalQuestions,
          results: results,
          previousErrorCounts: _errorCounts,
        );
        
        // Получить неправильные ответы для обратной связи
        final wrongAnswers = _answers
            .where((a) => !a.isCorrect)
            .map((a) => {
              'question': a.question,
              'userAnswer': a.userAnswer,
              'correctAnswer': a.correctAnswer,
            })
            .toList();
        
        // НЕ генерируем обратную связь автоматически - только по клику
        // Обновить текущий уровень
        _currentLevel = updatedProgress.currentLevel;
      } catch (e) {
        print('[QuizPlayScreen] Error updating progress: $e');
      }
    }

    // Сохранить результат через Provider
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final saved = await quizProvider.saveResult(
      userId: user.id,
      setId: widget.studySet.id,
      setTitle: widget.studySet.title,
      score: scorePercent,
      totalQuestions: totalQuestions,
      correctAnswers: correctCount,
      durationSeconds: totalDuration,
      answers: _answers.map((a) => a.toJson()).toList(),
    );
    
    if (!saved) {
      print('[Quiz] Warning: Failed to save result to server');
    }
    
    // Проверить достижения
    try {
      // Получить количество пройденных квизов (можно из API или локально)
      await _achievementsService.checkAndUnlockAchievements(
        quizCount: 1, // Будет накапливаться при каждом квизе
        maxLevel: widget.mode == QuizMode.training ? _currentLevel : null,
      );
      
      // Если получил 100%, разблокировать достижение
      if (scorePercent == 100) {
        await _achievementsService.checkAndUnlockAchievements(
          quizScore: 100, // Используется для достижения quiz_perfect
        );
      }
    } catch (e) {
      print('[Quiz] Error checking achievements: $e');
    }

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

    // Navigate to summary page
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizSummaryPage(
            result: quizResult,
            studySet: widget.studySet,
            aiFeedback: widget.mode == QuizMode.training ? _aiFeedback : null,
            currentLevel: widget.mode == QuizMode.training ? _currentLevel : null,
          ),
        ),
      );
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _isFlipped = false;
      });
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    
    final currentCards = _currentCards;
    if (_isLoadingTrainingData || _isGeneratingOptions || currentCards.isEmpty) {
      final progress = _adaptiveCards.isNotEmpty && _isGeneratingOptions
          ? _generatedOptionsCount / _adaptiveCards.length
          : 0.0;
      
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: textColor),
            onPressed: widget.onBack,
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
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              const SizedBox(height: 24),
              Text(
                _isGeneratingOptions 
                    ? 'Генерируем варианты ответов...\n$_generatedOptionsCount из ${_adaptiveCards.length}'
                    : 'Загрузка...',
                style: TextStyle(color: subtextColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (_isGeneratingOptions && _adaptiveCards.isNotEmpty) ...[
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
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    final currentCard = currentCards[_currentCardIndex];
    final progress = (_currentCardIndex + 1) / currentCards.length;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    // Для режима тренировки показываем Kahoot-стиль UI
    if (widget.mode == QuizMode.training && _answerOptions.isNotEmpty) {
      return _buildTrainingModeUI(context, currentCard, progress, isDark, bgColor, cardColor, textColor, subtextColor);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: widget.onBack,
        ),
        title: Text(
          widget.studySet.title,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
          
          // Card counter
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${_currentCardIndex + 1} / ${_currentCards.length}',
              style: TextStyle(
                color: subtextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Flip card
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final isShowingFront = _animation.value < 0.5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(math.pi * _animation.value),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 40,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: isShowingFront
                            ? _buildCardFront(currentCard.term, isDark)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildCardBack(currentCard.definition, isDark),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Flip button
                if (!_isFlipped)
                  TextButton(
                    onPressed: _flipCard,
                    child: const Text(
                      'Показать ответ',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                
                // Knowledge buttons (shown when flipped)
                if (_isFlipped) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAsUnknown,
                          icon: const Icon(LucideIcons.x, size: 20),
                          label: const Text('Не знаю'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _markAsKnown,
                          icon: const Icon(LucideIcons.check, size: 20),
                          label: const Text('Знаю'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                const SizedBox(height: 16),
                
                // Navigation and progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _currentCardIndex > 0 ? _previousCard : null,
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _currentCardIndex > 0 
                              ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                              : (isDark ? Colors.grey[900]! : Colors.grey[300]!),
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.arrowLeft,
                          color: _currentCardIndex > 0 
                              ? textColor
                              : subtextColor,
                        ),
                      ),
                    ),
                    
                    // Real progress indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.0 : 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.checkCircle2,
                            color: Colors.green[400],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_knownCards.length}',
                            style: TextStyle(
                              color: Colors.green[400],
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.xCircle,
                            color: Colors.red[400],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_unknownCards.length}',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    IconButton(
                      onPressed: _currentCardIndex < _currentCards.length - 1 
                          ? _nextCard
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _currentCardIndex < _currentCards.length - 1
                              ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                              : (isDark ? Colors.grey[900]! : Colors.grey[300]!),
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.arrowRight,
                          color: _currentCardIndex < _currentCards.length - 1
                              ? textColor
                              : subtextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrainingModeUI(BuildContext context, StudyCard currentCard, double progress, 
      bool isDark, Color bgColor, Color cardColor, Color textColor, Color? subtextColor) {
    final options = _answerOptions[_currentCardIndex];
    final correctIndex = _correctIndices[_currentCardIndex];
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.studySet.title,
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (_currentLevel > 0)
              Text(
                'Уровень $_currentLevel',
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
          ],
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
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          
          // Question counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Level indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.trendingUp, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Уровень $_currentLevel',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Text(
                  '${_currentCardIndex + 1} / ${_currentCards.length}',
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
                        backgroundColor = Colors.green.withOpacity(0.2);
                        borderColor = Colors.green;
                        textColorOption = Colors.green;
                      } else if (isSelected && !isCorrectAnswer) {
                        backgroundColor = Colors.red.withOpacity(0.2);
                        borderColor = Colors.red;
                        textColorOption = Colors.red;
                      } else if (!isSelected && isCorrectAnswer) {
                        backgroundColor = Colors.green.withOpacity(0.1);
                        borderColor = Colors.green.withOpacity(0.5);
                        textColorOption = Colors.green;
                      } else {
                        backgroundColor = cardColor;
                        borderColor = Colors.grey.withOpacity(0.3);
                        textColorOption = textColor;
                      }
                    } else {
                      backgroundColor = cardColor;
                      borderColor = isSelected 
                          ? const Color(0xFF10B981)
                          : Colors.grey.withOpacity(0.3);
                      textColorOption = textColor;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: showResult ? null : () => _selectTrainingAnswer(index),
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

  Widget _buildCardFront(String term, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF374151),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              term,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(String definition, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              definition,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
