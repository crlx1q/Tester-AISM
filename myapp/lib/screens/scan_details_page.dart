import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';
import '../services/ai_history_service.dart';
import '../models/study_set.dart';
import '../services/study_sets_service.dart';
import 'create_set_page.dart';
import 'quiz_page.dart';

class ScanDetailsPage extends StatefulWidget {
  const ScanDetailsPage({Key? key}) : super(key: key);

  @override
  State<ScanDetailsPage> createState() => _ScanDetailsPageState();
}

class _ScanDetailsPageState extends State<ScanDetailsPage> {
  File? _imageFile;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;
  int? _usageRemaining;
  int? _usageLimit;
  
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();
  final AiHistoryService _history = AiHistoryService();

  @override
  void initState() {
    super.initState();
    // Auto-open camera/gallery on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage();
    });
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: Colors.white),
              title: const Text(
                'Камера',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image, color: Colors.white),
              title: const Text(
                'Галерея',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _errorMessage = null;
        });
        _analyzeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при выборе изображения: $e';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не найден');
      }

      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _mimeFromPath(_imageFile!.path);
      final resp = await _api.aiScan(
        userId: userId,
        mimeType: mimeType,
        base64Image: base64Image,
      );

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
      
      final summary = (data['summary'] ?? '').toString().trim();
      final keyPoints = List<String>.from(data['keyPoints'] ?? const []);
      final questions = List<String>.from(data['questions'] ?? const []);
      
      print('[AI Scan] Summary length: ${summary.length}');
      print('[AI Scan] Key points count: ${keyPoints.length}');
      print('[AI Scan] Questions count: ${questions.length}');
      
      if (summary.isEmpty && keyPoints.isEmpty && questions.isEmpty) {
        throw Exception('Сервер вернул пустой результат. Попробуйте использовать изображение лучшего качества.');
      }
      
      setState(() {
        _analysisResult = {
          'summary': summary,
          'keyPoints': keyPoints,
          'questions': questions,
        };
        _isAnalyzing = false;
      });

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Анализ конспекта',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(LucideIcons.camera, color: Colors.white),
              onPressed: _pickImage,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_imageFile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.scanLine,
              color: Colors.grey[700],
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'Выберите изображение для анализа',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(LucideIcons.camera),
              label: const Text('Выбрать фото'),
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
      );
    }

    if (_isAnalyzing) {
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

    if (_errorMessage != null) {
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
                onPressed: _pickImage,
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

    return SingleChildScrollView(
      child: Column(
        children: [
          // usage chip (optional minimal UI)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.sparkles, color: Color(0xFF6366F1), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _usageRemaining != null && _usageLimit != null
                            ? 'AI анализ готов • Осталось: $_usageRemaining/$_usageLimit'
                            : 'AI анализ готов',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Image preview
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 250,
              ),
            ),
          ),

          // Analysis results
          if (_analysisResult != null) ...[
            // Summary
            if (_analysisResult!['summary'] != null && 
                (_analysisResult!['summary'] as String).trim().isNotEmpty)
              _buildSection(
                icon: LucideIcons.fileText,
                title: 'Краткая сводка',
                color: const Color(0xFF6366F1),
                content: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _analysisResult!['summary'],
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

            // Key Points
            if (_analysisResult!['keyPoints'] != null && 
                (_analysisResult!['keyPoints'] as List).isNotEmpty)
              _buildSection(
                icon: LucideIcons.key,
                title: 'Ключевые моменты',
                color: Colors.amber,
                content: Column(
                  children: (_analysisResult!['keyPoints'] as List).map((point) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              point.toString(),
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Questions
            if (_analysisResult!['questions'] != null && 
                (_analysisResult!['questions'] as List).isNotEmpty)
              _buildSection(
                icon: LucideIcons.helpCircle,
                title: 'Возможные вопросы для теста',
                color: Colors.green,
                content: Column(
                  children: (_analysisResult!['questions'] as List).map((question) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
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
                                color: Colors.grey[300],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createStudySetFromAnalysis,
                      icon: const Icon(LucideIcons.swords),
                      label: const Text('Создать квиз'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}
