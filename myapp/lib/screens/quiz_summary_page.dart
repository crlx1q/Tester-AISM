import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/quiz_result.dart';
import '../models/study_set.dart';
import '../services/gemini_service.dart';
import '../services/profile_notifier.dart';
import '../services/study_sets_service.dart';
import 'package:provider/provider.dart';
import 'quiz_page.dart';
import 'quiz_mode_selection_page.dart';

class QuizSummaryPage extends StatefulWidget {
  final QuizResult result;
  final StudySet studySet;
  final VoidCallback? onRetryIncorrect;
  final VoidCallback? onCreateCards;
  final String? aiFeedback; // Обратная связь от ИИ для режима тренировки
  final int? currentLevel; // Текущий уровень для режима тренировки

  const QuizSummaryPage({
    Key? key,
    required this.result,
    required this.studySet,
    this.onRetryIncorrect,
    this.onCreateCards,
    this.aiFeedback,
    this.currentLevel,
  }) : super(key: key);

  @override
  State<QuizSummaryPage> createState() => _QuizSummaryPageState();
}

class _QuizSummaryPageState extends State<QuizSummaryPage> {
  String? _generatedFeedback;
  bool _isGeneratingFeedback = false;
  final GeminiService _geminiService = GeminiService();

  Future<void> _generateFeedback() async {
    if (_isGeneratingFeedback) return;
    
    setState(() => _isGeneratingFeedback = true);
    
    try {
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) return;
      
      final wrongAnswers = widget.result.answers
          .where((a) => !a.isCorrect)
          .map((a) => {
            'question': a.question,
            'userAnswer': a.userAnswer,
            'correctAnswer': a.correctAnswer,
          })
          .toList();
      
      final feedback = await _geminiService.generatePersonalizedFeedback(
        topic: widget.studySet.title,
        wrongAnswers: wrongAnswers,
        level: widget.currentLevel ?? 1,
        score: widget.result.correctAnswers / widget.result.totalQuestions,
        userId: user.id,
      );
      
      if (mounted) {
        setState(() {
          _generatedFeedback = feedback;
          _isGeneratingFeedback = false;
        });
      }
    } catch (e) {
      print('[Summary] Error generating feedback: $e');
      if (mounted) {
        setState(() {
          _generatedFeedback = 'Не удалось сгенерировать сводку. Попробуйте позже.';
          _isGeneratingFeedback = false;
        });
      }
    }
  }
  
  Future<void> _retryIncorrect() async {
    // Получить неправильные ответы - использовать question как term или definition
    final wrongAnswers = widget.result.answers.where((a) => !a.isCorrect).toList();
    
    if (wrongAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет ошибочных вопросов для повтора')),
      );
      return;
    }
    
    // Создать карточки из неправильных ответов
    // Важно: в режиме тренировки answer.question это term (термин из карточки)
    final wrongCards = <StudyCard>[];
    
    for (final answer in wrongAnswers) {
      try {
        // Искать карточку в оригинальном наборе
        // В режиме тренировки answer.question = card.term (вопрос = термин)
        final originalCard = widget.studySet.cards.firstWhere(
          (card) {
            // Проверяем точное совпадение и без учета регистра
            final questionLower = answer.question.trim().toLowerCase();
            final termLower = card.term.trim().toLowerCase();
            final definitionLower = card.definition.trim().toLowerCase();
            
            return termLower == questionLower || definitionLower == questionLower;
          },
        );
        wrongCards.add(originalCard);
      } catch (e) {
        // Если не нашли оригинальную карточку, создаем новую
        print('[RetryIncorrect] Card not found for question: ${answer.question}');
        wrongCards.add(StudyCard(
          term: answer.question,
          definition: answer.correctAnswer,
        ));
      }
    }
    
    if (wrongCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти карточки для повтора')),
      );
      return;
    }
    
    // Создать временный набор для повтора с уникальным ID
    final retrySetId = 'retry_${DateTime.now().millisecondsSinceEpoch}';
    final retrySet = StudySet(
      id: retrySetId,
      title: 'Повтор: ${widget.studySet.title}',
      cards: wrongCards,
      icon: widget.studySet.icon,
      color: widget.studySet.color,
      createdAt: DateTime.now(),
    );
    
    // Сохранить набор временно, чтобы QuizPage мог его загрузить
    await StudySetsService().saveStudySet(retrySet);
    
    print('[RetryIncorrect] Created retry set: ${retrySet.title} with ${wrongCards.length} cards');
    print('[RetryIncorrect] Set ID: $retrySetId');
    
    if (mounted) {
      // Небольшая задержка для гарантии сохранения
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Вернуться к квизу с этим набором
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPage(setId: retrySetId, mode: QuizMode.training),
        ),
      );
    }
  }
  
  Future<void> _createCardsFromErrors() async {
    try {
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) return;
      
      final wrongAnswers = widget.result.answers.where((a) => !a.isCorrect).toList();
      if (wrongAnswers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет ошибок для создания карточек')),
        );
        return;
      }
      
      // Создать карточки из неправильных ответов
      // Попробовать найти оригинальную карточку в наборе
      final errorCards = wrongAnswers.map((answer) {
        try {
          // Искать карточку где term или definition совпадает с вопросом
          final originalCard = widget.studySet.cards.firstWhere(
            (card) => card.term.trim().toLowerCase() == answer.question.trim().toLowerCase() ||
                      card.definition.trim().toLowerCase() == answer.question.trim().toLowerCase(),
            orElse: () => StudyCard(
              term: answer.question,
              definition: answer.correctAnswer,
            ),
          );
          return originalCard;
        } catch (e) {
          // Если не нашли, создаем новую карточку
          return StudyCard(
            term: answer.question,
            definition: answer.correctAnswer,
          );
        }
      }).toList();
      
      final errorSetId = DateTime.now().millisecondsSinceEpoch.toString();
      final errorSet = StudySet(
        id: errorSetId,
        title: 'Ошибки: ${widget.studySet.title}',
        cards: errorCards,
        icon: widget.studySet.icon,
        color: Colors.red,
        createdAt: DateTime.now(),
      );
      
      // Сохранить набор
      await StudySetsService().saveStudySet(errorSet);
      
      if (mounted) {
        // Показать диалог с информацией и возможностью перейти к набору
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Набор создан!'),
            content: Text(
              'Набор "${errorSet.title}" (${errorCards.length} карточек) был сохранен.\n\n'
              'Вы можете найти его в списке наборов на главной странице.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ОК'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Закрыть диалог
                  // Перейти на главную страницу (список наборов)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Открыть наборы'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('[CreateCardsFromErrors] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания карточек: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

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
          'Результаты квиза',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Card
            _buildScoreCard(cardColor, textColor, subtextColor),
            
            const SizedBox(height: 24),
            
            // Stats
            _buildStatsRow(cardColor, textColor, subtextColor),
            
            const SizedBox(height: 24),
            
            // AI Feedback for training mode
            if (widget.aiFeedback != null || _generatedFeedback != null) ...[
              _buildAIFeedbackCard(
                _generatedFeedback ?? widget.aiFeedback ?? '',
                cardColor, 
                textColor, 
                subtextColor,
                isGenerating: _isGeneratingFeedback,
                onGenerate: widget.aiFeedback == null ? _generateFeedback : null,
              ),
              const SizedBox(height: 24),
            ] else if (widget.currentLevel != null) ...[
              // Показать кнопку для генерации обратной связи
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.brain,
                      color: Color(0xFF6366F1),
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Получить обратную связь от ИИ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingFeedback ? null : _generateFeedback,
                      icon: _isGeneratingFeedback 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.sparkles, size: 18),
                      label: Text(_isGeneratingFeedback ? 'Генерация...' : 'Сгенерировать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Level indicator for training mode
            if (widget.currentLevel != null) ...[
              _buildLevelIndicator(widget.currentLevel!, cardColor, textColor, subtextColor),
              const SizedBox(height: 24),
            ],
            
            // Action Buttons
            _buildActionButtons(context, cardColor, textColor),
            
            const SizedBox(height: 24),
            
            // Questions Review
            Text(
              'Обзор вопросов',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            
            ...widget.result.answers.asMap().entries.map((entry) {
              final index = entry.key;
              final answer = entry.value;
              return _buildQuestionCard(
                index + 1,
                answer,
                cardColor,
                textColor,
                subtextColor,
              );
            }).toList(),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(Color cardColor, Color textColor, Color? subtextColor) {
    final scoreColor = widget.result.score >= 80
        ? Colors.green
        : widget.result.score >= 60
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withOpacity(0.1),
                border: Border.all(color: scoreColor, width: 4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.result.score}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      '${widget.result.correctAnswers}/${widget.result.totalQuestions}',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.result.score >= 80
                ? 'Отлично!'
                : widget.result.score >= 60
                    ? 'Хорошо!'
                    : 'Нужно повторить',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.studySet.title,
            style: TextStyle(
              fontSize: 14,
              color: subtextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color cardColor, Color textColor, Color? subtextColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            LucideIcons.clock,
            'Время',
            widget.result.formattedDuration,
            cardColor,
            textColor,
            subtextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            LucideIcons.zap,
            'Средн/вопр',
            widget.result.averageTimePerQuestion,
            cardColor,
            textColor,
            subtextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color cardColor, Color textColor) {
    return Column(
      children: [
        if (widget.result.correctAnswers < widget.result.totalQuestions)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onRetryIncorrect ?? _retryIncorrect,
              icon: const Icon(LucideIcons.rotateCcw, size: 20),
              label: const Text('Повторить ошибочные'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (widget.result.correctAnswers < widget.result.totalQuestions)
          const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onCreateCards ?? _createCardsFromErrors,
            icon: const Icon(LucideIcons.plus, size: 20),
            label: const Text('Создать карточки из ошибок'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    int number,
    dynamic answer,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    final isCorrect = answer.isCorrect ?? false;
    final statusColor = isCorrect ? Colors.green : Colors.red;
    final statusIcon = isCorrect ? LucideIcons.checkCircle2 : LucideIcons.xCircle;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Вопрос $number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (answer.timeSpent != null)
                Text(
                  '${answer.timeSpent}с',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer.question ?? '',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
            ),
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ваш ответ:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer.userAnswer ?? '',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Правильный ответ:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    answer.correctAnswer ?? '',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIFeedbackCard(
    String feedback, 
    Color cardColor, 
    Color textColor, 
    Color? subtextColor,
    {bool isGenerating = false, VoidCallback? onGenerate}
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Обратная связь от ИИ-наставника',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isGenerating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (feedback.isNotEmpty)
            MarkdownBody(
              data: feedback,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.5,
                ),
                strong: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                em: TextStyle(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
                code: TextStyle(
                  backgroundColor: cardColor,
                  color: textColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(int level, Color cardColor, Color textColor, Color? subtextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.trendingUp,
            color: Color(0xFF10B981),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уровень сложности',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index < level
                            ? const Color(0xFF10B981)
                            : (subtextColor ?? Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Text(
            'Уровень $level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

