import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../models/recording_model.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';
import '../services/ai_history_service.dart';

class RecordingDetailsPage extends StatefulWidget {
  final Recording recording;
  const RecordingDetailsPage({super.key, required this.recording});

  @override
  State<RecordingDetailsPage> createState() => _RecordingDetailsPageState();
}

class _RecordingDetailsPageState extends State<RecordingDetailsPage>
    with SingleTickerProviderStateMixin {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _progressTimer;
  late TextEditingController _transcriptionController;
  final ApiService _api = ApiService();
  final AiHistoryService _history = AiHistoryService();
  bool _isProcessing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _transcriptionController =
        TextEditingController(text: widget.recording.transcription);
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();

      // Parse duration from recording string (MM:SS format)
      final parts = widget.recording.duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        _duration = Duration(minutes: minutes, seconds: seconds);
      }

      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      print('Player init error: $e');
    }
  }

  @override
  void dispose() {
    _stopProgressTimer();
    _player.closePlayer();
    _transcriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayer() async {
    if (!_isPlayerInitialized || widget.recording.path == null) return;

    try {
      if (_isPlaying) {
        // Stop playing
        await _player.stopPlayer();
        _stopProgressTimer();
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      } else {
        // Start playing
        await _player.startPlayer(
          fromURI: widget.recording.path,
          codec: Codec.aacADTS,
          whenFinished: () {
            _stopProgressTimer();
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          },
        );
        _startProgressTimer();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Player error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          // Simple progress calculation based on duration
          if (_duration.inMilliseconds > 0) {
            _position = Duration(
                milliseconds: (_position.inMilliseconds + 200)
                    .clamp(0, _duration.inMilliseconds));

            // Stop when reached end
            if (_position.inMilliseconds >= _duration.inMilliseconds) {
              _togglePlayer();
            }
          }
        });
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _seekTo(double value) {
    if (_duration.inMilliseconds > 0) {
      setState(() {
        _position = Duration(milliseconds: value.toInt());
      });
    }
  }

  Future<void> _processWithAI() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (widget.recording.path == null) {
        throw Exception('Нет файла записи');
      }

      final userId = await UserPrefs.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не найден');
      }

      // Try to find the file - it might be a full path or just a filename
      File audioFile = File(widget.recording.path!);

      // If the path is not absolute, try to construct it from app directory
      if (!await audioFile.exists()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fullPath = '${appDir.path}/${widget.recording.path}';
        audioFile = File(fullPath);
        print('[AI Voice] Trying full path: $fullPath');
      }

      if (!await audioFile.exists()) {
        print('[AI Voice] File not found. Path: ${widget.recording.path}');
        throw Exception(
            'Файл записи не найден: ${widget.recording.path}\nПроверьте, что запись была сохранена корректно.');
      }

      // Read audio and send to server
      print('[AI Voice] Reading file: ${audioFile.path}');
      final bytes = await audioFile.readAsBytes();
      print('[AI Voice] File size: ${bytes.length} bytes');
      final base64Audio = base64Encode(bytes);
      final resp = await _api.aiVoice(
        userId: userId,
        mimeType: 'audio/aac',
        base64Audio: base64Audio,
      );

      if (resp['success'] != true) {
        final msg = resp['message'] ?? 'Ошибка обработки аудио';
        throw Exception(msg);
      }

      final data = resp['data'] ?? {};
      setState(() {
        widget.recording.transcription =
            (data['transcription'] ?? '').toString();
        widget.recording.summary = (data['summary'] ?? '').toString();
        widget.recording.keyPoints =
            (data['keyPoints'] as List?)?.join('\n• ') ?? '';
        widget.recording.testQuestions = (data['questions'] as List?)
                ?.asMap()
                .entries
                .map((e) => '${e.key + 1}. ${e.value}')
                .join('\n') ??
            '';
        _transcriptionController.text = widget.recording.transcription ?? '';
      });

      // Save to AI Notebook (AiLecture + NotebookEntry)
      try {
        final keyConcepts =
            (data['keyConcepts'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        final questions =
            (data['questions'] as List?)?.map((e) => e.toString()).toList() ??
                [];

        await _api.createAiLecture(
          userId: userId,
          recordingId: widget.recording.id,
          title: widget.recording.title,
          durationSeconds: _duration.inSeconds,
          transcription: widget.recording.transcription ?? '',
          summary: widget.recording.summary ?? '',
          keyConcepts: keyConcepts,
          questions: questions,
          tags: [],
        );
        print('[AI Voice] Successfully saved to AI Notebook');
      } catch (e) {
        print('[AI Voice] Failed to save to Notebook: $e');
        // Don't fail the whole process if Notebook save fails
      }

      // Local history save
      await _history.addVoice({
        'transcription': widget.recording.transcription,
        'summary': widget.recording.summary,
        'keyPoints': widget.recording.keyPoints?.split('\n') ?? [],
        'questions': widget.recording.testQuestions?.split('\n') ?? [],
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Persist ai meta if provided
      if (resp['ai'] != null) {
        await UserPrefs.updateAiMeta(resp['ai'] as Map<String, dynamic>?);
      }
    } catch (e) {
      print('[AI Voice] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final subtextColor =
        isDarkMode ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);
    final cardColor =
        isDarkMode ? const Color(0xFF1f2937) : Colors.white;
    final bgColor = isDarkMode ? const Color(0xFF111827) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, textColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildEnhancedPlayer(cardColor, subtextColor, textColor),
                    const SizedBox(height: 24),
                    _buildStatistics(cardColor, textColor, subtextColor),
                    const SizedBox(height: 24),
                    if (widget.recording.summary == null)
                      _buildProcessingSection(
                          cardColor, textColor, subtextColor)
                    else
                      _buildEnhancedResults(cardColor, textColor, subtextColor),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recording.title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Длительность: ${widget.recording.duration}',
                  style: TextStyle(
                      fontSize: 12, color: textColor.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          _buildActionMenu(context, textColor),
        ],
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context, Color textColor) {
    return PopupMenuButton<String>(
      icon: Icon(LucideIcons.moreVertical, color: textColor),
      onSelected: (value) {
        switch (value) {
          case 'copy_all':
            _copyAllResults();
            break;
          case 'export':
            _showExportDialog(context);
            break;
          case 'reprocess':
            _processWithAI();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'copy_all',
          child: Row(
            children: [
              Icon(LucideIcons.copy, size: 18),
              SizedBox(width: 12),
              Text('Копировать все'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(LucideIcons.download, size: 18),
              SizedBox(width: 12),
              Text('Экспортировать'),
            ],
          ),
        ),
        if (widget.recording.summary != null)
          const PopupMenuItem(
            value: 'reprocess',
            child: Row(
              children: [
                Icon(LucideIcons.refreshCw, size: 18),
                SizedBox(width: 12),
                Text('Переобработать'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancedPlayer(
      Color cardColor, Color subtextColor, Color textColor) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(LucideIcons.mic, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аудиозапись',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.recording.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Wave visualization placeholder
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(40, (index) {
                      final height = 10.0 + (index % 5) * 8.0;
                      final isPast = (index / 40) < progress;
                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: isPast
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Progress slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.3),
            ),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds
                  .toDouble()
                  .clamp(0.0, _duration.inMilliseconds.toDouble()),
              onChanged: _seekTo,
            ),
          ),
          const SizedBox(height: 8),
          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Player controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.skipBack,
                    color: Colors.white, size: 28),
                onPressed: () {
                  final newPos = Duration(
                      milliseconds: (_position.inMilliseconds - 10000)
                          .clamp(0, _duration.inMilliseconds));
                  _seekTo(newPos.inMilliseconds.toDouble());
                },
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: const Color(0xFF6366F1),
                    size: 32,
                  ),
                  onPressed: _togglePlayer,
                  iconSize: 32,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(LucideIcons.skipForward,
                    color: Colors.white, size: 28),
                onPressed: () {
                  final newPos = Duration(
                      milliseconds: (_position.inMilliseconds + 10000)
                          .clamp(0, _duration.inMilliseconds));
                  _seekTo(newPos.inMilliseconds.toDouble());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildStatistics(
      Color cardColor, Color textColor, Color subtextColor) {
    final wordCount = widget.recording.transcription?.split(' ').length ?? 0;
    final readingTime = (wordCount / 200).ceil(); // ~200 words per minute

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.clock,
            label: 'Длительность',
            value: widget.recording.duration,
            color: const Color(0xFF6366F1),
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.type,
            label: 'Слов',
            value: wordCount > 0 ? '$wordCount' : '—',
            color: const Color(0xFF8B5CF6),
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.bookOpen,
            label: 'Чтение',
            value: readingTime > 0 ? '${readingTime}м' : '—',
            color: const Color(0xFFEC4899),
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingSection(
      Color cardColor, Color textColor, Color subtextColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 48,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isProcessing ? 'Обработка записи...' : 'Готово к обработке',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isProcessing
                ? 'ИИ анализирует вашу запись. Это может занять некоторое время.'
                : 'Используйте ИИ для расшифровки и анализа вашей записи лекции',
            style: TextStyle(
              fontSize: 14,
              color: subtextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (_isProcessing)
            Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processWithAI,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(LucideIcons.sparkles, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Начать обработку с ИИ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildFeatureChip(
                  'Расшифровка', LucideIcons.fileText, subtextColor),
              _buildFeatureChip('Сводка', LucideIcons.alignLeft, subtextColor),
              _buildFeatureChip(
                  'Ключевые моменты', LucideIcons.checkCircle, subtextColor),
              _buildFeatureChip(
                  'Тестовые вопросы', LucideIcons.helpCircle, subtextColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6366F1)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedResults(
      Color cardColor, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Результаты анализа',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.checkCircle,
                      size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'Готово',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: textColor.withOpacity(0.6),
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(LucideIcons.fileText, size: 18),
                text: 'Расшифровка',
              ),
              Tab(
                icon: Icon(LucideIcons.alignLeft, size: 18),
                text: 'Сводка',
              ),
              Tab(
                icon: Icon(LucideIcons.list, size: 18),
                text: 'Моменты',
              ),
              Tab(
                icon: Icon(LucideIcons.helpCircle, size: 18),
                text: 'Вопросы',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Tab content
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(
                widget.recording.transcription ?? '',
                'Расшифровка записи',
                LucideIcons.fileText,
                cardColor,
                textColor,
                subtextColor,
                editable: true,
              ),
              _buildTabContent(
                widget.recording.summary ?? '',
                'Краткая сводка',
                LucideIcons.alignLeft,
                cardColor,
                textColor,
                subtextColor,
              ),
              _buildTabContent(
                widget.recording.keyPoints ?? '',
                'Ключевые моменты',
                LucideIcons.list,
                cardColor,
                textColor,
                subtextColor,
              ),
              _buildTabContent(
                widget.recording.testQuestions ?? '',
                'Тестовые вопросы',
                LucideIcons.helpCircle,
                cardColor,
                textColor,
                subtextColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(
    String content,
    String title,
    IconData icon,
    Color cardColor,
    Color textColor,
    Color subtextColor, {
    bool editable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.copy, size: 18),
                onPressed: () => _copyToClipboard(content),
                tooltip: 'Копировать',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: editable
                  ? TextFormField(
                      controller: _transcriptionController,
                      maxLines: null,
                      style: TextStyle(
                        color: textColor,
                        height: 1.6,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Расшифровка появится здесь...',
                        hintStyle:
                            TextStyle(color: subtextColor.withOpacity(0.5)),
                      ),
                    )
                  : Text(
                      content.isEmpty ? 'Нет данных' : content,
                      style: TextStyle(
                        color: textColor,
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(LucideIcons.check, color: Colors.white, size: 18),
            SizedBox(width: 12),
            Text('Скопировано в буфер обмена'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllResults() {
    final buffer = StringBuffer();
    buffer.writeln('📝 ${widget.recording.title}');
    buffer.writeln('⏱️ ${widget.recording.duration}');
    buffer.writeln('\n' + '=' * 50 + '\n');

    if (widget.recording.transcription != null) {
      buffer.writeln('🎤 РАСШИФРОВКА:');
      buffer.writeln(widget.recording.transcription);
      buffer.writeln('\n' + '=' * 50 + '\n');
    }

    if (widget.recording.summary != null) {
      buffer.writeln('📋 КРАТКАЯ СВОДКА:');
      buffer.writeln(widget.recording.summary);
      buffer.writeln('\n' + '=' * 50 + '\n');
    }

    if (widget.recording.keyPoints != null) {
      buffer.writeln('✨ КЛЮЧЕВЫЕ МОМЕНТЫ:');
      buffer.writeln(widget.recording.keyPoints);
      buffer.writeln('\n' + '=' * 50 + '\n');
    }

    if (widget.recording.testQuestions != null) {
      buffer.writeln('❓ ТЕСТОВЫЕ ВОПРОСЫ:');
      buffer.writeln(widget.recording.testQuestions);
    }

    _copyToClipboard(buffer.toString());
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.download, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Экспортировать'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(LucideIcons.fileText, color: Color(0xFF6366F1)),
              title: const Text('Текстовый файл (.txt)'),
              onTap: () {
                Navigator.pop(context);
                _exportAsText();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.share2, color: Color(0xFF8B5CF6)),
              title: const Text('Поделиться'),
              onTap: () {
                Navigator.pop(context);
                _shareResults();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('${widget.recording.title}');
    buffer.writeln('Длительность: ${widget.recording.duration}');
    buffer.writeln('\n${'=' * 50}\n');

    if (widget.recording.transcription != null) {
      buffer.writeln('РАСШИФРОВКА:\n${widget.recording.transcription}\n');
    }
    if (widget.recording.summary != null) {
      buffer.writeln('СВОДКА:\n${widget.recording.summary}\n');
    }
    if (widget.recording.keyPoints != null) {
      buffer.writeln('КЛЮЧЕВЫЕ МОМЕНТЫ:\n${widget.recording.keyPoints}\n');
    }
    if (widget.recording.testQuestions != null) {
      buffer.writeln('ВОПРОСЫ:\n${widget.recording.testQuestions}');
    }

    // Here you would typically save to file or share
    _copyToClipboard(buffer.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Экспортировано в буфер обмена'),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareResults() {
    _copyAllResults();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Результаты скопированы. Вставьте в любое приложение для отправки.'),
        backgroundColor: const Color(0xFF8B5CF6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
