import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';
import '../services/ai_history_service.dart';
import '../models/study_set.dart';
import '../services/study_sets_service.dart';
import 'create_set_page.dart';
import 'quiz_page.dart';

class ScanResultsPage extends StatefulWidget {
  final XFile image;
  const ScanResultsPage({super.key, required this.image});

  @override
  State<ScanResultsPage> createState() => _ScanResultsPageState();
}

class _ScanResultsPageState extends State<ScanResultsPage> {
  final ApiService _api = ApiService();
  final AiHistoryService _history = AiHistoryService();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;
  int? _usageRemaining;
  int? _usageLimit;
  String? _imageBase64;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не найден');
      }

      final bytes = await File(widget.image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      _imageBase64 = 'data:image/jpeg;base64,$base64Image';

      // Логируем размер для отладки
      print(
          '[SCAN] Image size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');
      print(
          '[SCAN] Base64 size: ${(base64Image.length / 1024).toStringAsFixed(2)} KB');

      final mimeType = _mimeFromPath(widget.image.path);
      final startTime = DateTime.now();

      final resp = await _api.aiScan(
        userId: userId,
        mimeType: mimeType,
        base64Image: base64Image,
      );

      final duration = DateTime.now().difference(startTime);
      print('[SCAN] AI analysis took: ${duration.inSeconds} seconds');

      if (resp['success'] != true) {
        final message = resp['message'] ?? 'Ошибка анализа изображения';
        throw Exception(message);
      }

      final data = resp['data'] ?? {};
      final ai = resp['ai'] as Map<String, dynamic>?;
      final usageMap = (ai?['usage'] as Map?)?.cast<String, dynamic>();
      final scanUsage = (usageMap?['scan'] as Map?)?.cast<String, dynamic>();
      if (scanUsage != null) {
        final remRaw = scanUsage['remaining'];
        final limRaw = scanUsage['limit'];
        _usageRemaining = remRaw is int ? remRaw : int.tryParse('$remRaw');
        _usageLimit = limRaw is int ? limRaw : int.tryParse('$limRaw');
      } else {
        _usageRemaining = null;
        _usageLimit = null;
      }
      setState(() {
        _analysisResult = {
          'summary': data['summary'] ?? '',
          'keyPoints': List<String>.from(data['keyPoints'] ?? const []),
          'questions': List<String>.from(data['questions'] ?? const []),
        };
        _isAnalyzing = false;
      });

      // Save to AI Notebook (AiScanNote + NotebookEntry)
      try {
        final concepts =
            (data['concepts'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        final formulas =
            (data['formulas'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        final questions =
            (data['questions'] as List?)?.map((e) => e.toString()).toList() ??
                [];

        await _api.createAiScanNote(
          userId: userId,
          title: 'Конспект ${DateTime.now().day}/${DateTime.now().month}',
          imageUrl: _imageBase64, // Сохраняем фото конспекта
          summary: _analysisResult!['summary'] as String,
          keyPoints: _analysisResult!['keyPoints'] as List<String>,
          concepts: concepts,
          formulas: formulas,
          questions: questions,
          tags: [],
          course: '',
          manualNotes: '',
        );
        print('[AI Scan] Successfully saved to AI Notebook');

        // Помечаем как сохраненное
        setState(() {
          _isSaved = true;
        });
      } catch (e) {
        print('[AI Scan] Failed to save to Notebook: $e');
        // Don't fail the whole process if Notebook save fails
      }

      // Report scan activity to stats (average 10 minutes per scan)
      try {
        await _api.reportActivity(
          userId: userId,
          type: 'scan',
          minutes: 10,
        );
        print('[STATS] Reported scan activity');
      } catch (e) {
        print('[STATS] Failed to report scan: $e');
      }

      // Save to local history
      await _history.addScan({
        'summary': _analysisResult!['summary'],
        'keyPoints': _analysisResult!['keyPoints'],
        'questions': _analysisResult!['questions'],
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Save AI meta to prefs
      if (resp['ai'] != null) {
        await UserPrefs.updateAiMeta(resp['ai'] as Map<String, dynamic>?);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка анализа: $e';
        _isAnalyzing = false;
      });
    }
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
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

  // Метод больше не нужен - сохранение происходит автоматически в _analyzeImage()
  void _showAlreadySavedMessage() {
    if (_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Конспект уже сохранен в AI Notebook!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _createStudySetFromAnalysis() async {
    if (_analysisResult == null) return;

    final cards = <StudyCard>[];

    // Convert key points to cards
    if (_analysisResult!['keyPoints'] != null) {
      for (final point in _analysisResult!['keyPoints']) {
        cards.add(StudyCard(
          term: 'Ключевой момент ${cards.length + 1}',
          definition: point.toString(),
        ));
      }
    }

    // Convert questions to cards
    if (_analysisResult!['questions'] != null) {
      for (final question in _analysisResult!['questions']) {
        cards.add(StudyCard(
          term: question.toString().split('?').first + '?',
          definition: 'Вопрос для самопроверки',
        ));
      }
    }

    if (cards.isNotEmpty) {
      final studySet = StudySet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Конспект от ${DateTime.now().day}.${DateTime.now().month}',
        cards: cards,
        icon: LucideIcons.bookOpen,
        color: Colors.purple,
        createdAt: DateTime.now(),
      );

      await StudySetsService().saveStudySet(studySet);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizPage(setId: studySet.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final cardColor =
        isDarkMode ? const Color(0xFF1f2937) : Colors.white;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _buildHeader(context, textColor),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(widget.image.path),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            if (_isAnalyzing)
              _buildLoadingIndicator()
            else if (_errorMessage != null)
              _buildError()
            else if (_analysisResult != null)
              _buildAiResults(cardColor, textColor, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textColor) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Результаты сканирования',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '✨ Магия AI в действии...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Анализируем ваш конспект',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              color: Colors.red[400],
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _analyzeImage,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Попробовать снова'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResults(Color cardColor, Color textColor, bool isDarkMode) {
    final subtextColor =
        isDarkMode ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Usage info
        if (_usageRemaining != null && _usageLimit != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.sparkles,
                          color: Color(0xFF6366F1), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI анализ готов • Осталось: $_usageRemaining/$_usageLimit',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_analysisResult!['summary'] != null &&
            _analysisResult!['summary'].toString().isNotEmpty)
          _buildAiSection(
              'Краткая сводка',
              _analysisResult!['summary'].toString(),
              cardColor,
              textColor,
              subtextColor,
              isDarkMode),
        const SizedBox(height: 16),
        if (_analysisResult!['keyPoints'] != null &&
            (_analysisResult!['keyPoints'] as List).isNotEmpty)
          _buildKeyPointsSection(
              _analysisResult!['keyPoints'] as List, cardColor, textColor, isDarkMode),
        const SizedBox(height: 16),
        if (_analysisResult!['questions'] != null &&
            (_analysisResult!['questions'] as List).isNotEmpty)
          _buildQuestionsSection(
              _analysisResult!['questions'] as List, cardColor, textColor, isDarkMode),
        const SizedBox(height: 24),

        // Action buttons
        Column(
          children: [
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaved ? _showAlreadySavedMessage : null,
                icon:
                    Icon(_isSaved ? LucideIcons.checkCircle : LucideIcons.save),
                label: Text(_isSaved ? 'Сохранено' : 'Сохранить конспект'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaved
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createStudySetFromAnalysis,
                    icon: const Icon(LucideIcons.swords),
                    label: const Text('Создать квиз'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateSetPage(),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.edit),
                    label: const Text('Редактировать'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiSection(String title, String content, Color cardColor,
      Color textColor, Color subtextColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            content,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyPointsSection(
      List keyPoints, Color cardColor, Color textColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.key, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text(
              'Ключевые моменты',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...keyPoints.map((point) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuestionsSection(
      List questions, Color cardColor, Color textColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.helpCircle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'Возможные вопросы для теста',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...questions.map((question) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.helpCircle,
                  color: Colors.green[400],
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
