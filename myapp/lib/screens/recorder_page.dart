import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording_model.dart';
import '../services/background_recording_service.dart';
import '../services/notification_service.dart';
import '../services/wakelock_service.dart';
import '../services/user_prefs.dart';
import '../services/api_service.dart';
import 'recording_details_page.dart';

enum RecordingFilter { all, aiReady, raw }

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  Timer? _timer;
  int _seconds = 0;
  AnimationController? _animationController;
  final List<Recording> _recordings = [];
  int _recordingCounter = 0;
  String? _recordingPath;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RecordingFilter _filter = RecordingFilter.all;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _initRecorder();
    _loadRecordings();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    _recorder.closeRecorder();
    _searchController.dispose();
    // Disable wakelock when disposing
    WakelockService.disable();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!_isRecorderInitialized) return;

    if (_isRecording) {
      // Stop recording and get the full path
      final recordedPath = await _recorder.stopRecorder();
      _timer?.cancel();

      // Disable wakelock to allow device to sleep
      await WakelockService.disable();

      // Stop background service and hide notification
      await BackgroundRecordingService.stopRecording(_timerText);

      // Use the returned path from stopRecorder if available, otherwise use the stored path
      final finalPath = recordedPath ?? _recordingPath;
      print('[Recorder] Recording stopped. Path: $finalPath');

      if (finalPath != null) {
        _showProcessingAndSave(finalPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ошибка: не удалось сохранить запись')),
          );
        }
      }
      setState(() => _isRecording = false);
    } else {
      // Request permissions
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Для записи нужен доступ к микрофону.')),
        );
        return;
      }

      // Request notification permission
      final notificationGranted =
          await NotificationService().requestNotificationPermissions();
      if (!notificationGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Разрешите уведомления для лучшего опыта записи.')),
        );
      }

      // Enable wakelock to prevent device from sleeping during recording
      await WakelockService.enable();

      _recordingCounter++;
      final fileName = 'recording_$_recordingCounter.aac';
      await _recorder.startRecorder(toFile: fileName, codec: Codec.aacADTS);
      _recordingPath = fileName;
      print('[Recorder] Recording started. File: $fileName');
      _startTimer();

      // Start background service and show notification
      await BackgroundRecordingService.startRecording();

      setState(() => _isRecording = true);
    }
  }

  void _startTimer() {
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  String get _timerText {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _saveRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final recordingsJson =
        _recordings.map((rec) => jsonEncode(rec.toJson())).toList();
    await prefs.setStringList('recordings', recordingsJson);
  }

  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final recordingsJson = prefs.getStringList('recordings');
    if (recordingsJson != null) {
      setState(() {
        _recordings.clear();
        _recordings.addAll(
            recordingsJson.map((rec) => Recording.fromJson(jsonDecode(rec))));
        _recordingCounter = _recordings.length;
      });
    }
  }

  List<Recording> get _filteredRecordings {
    return _recordings.where((recording) {
      final matchesSearch = _searchQuery.isEmpty ||
          recording.title.toLowerCase().contains(_searchQuery.toLowerCase());

      final hasAi = (recording.summary?.isNotEmpty ?? false) ||
          (recording.keyPoints?.isNotEmpty ?? false) ||
          (recording.testQuestions?.isNotEmpty ?? false) ||
          (recording.transcription?.isNotEmpty ?? false);

      final matchesFilter = switch (_filter) {
        RecordingFilter.all => true,
        RecordingFilter.aiReady => hasAi,
        RecordingFilter.raw => !hasAi,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showProcessingAndSave(String path) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Магия AI в действии...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () async {
      Navigator.of(context).pop();

      final newRecording = Recording(
        id: _recordingCounter.toString(),
        title: 'Запись лекции #${_recordingCounter}',
        duration: _timerText,
        path: path,
      );

      setState(() {
        _recordings.insert(0, newRecording);
      });

      await _saveRecordings();

      // Report recording activity to stats
      try {
        final userId = await UserPrefs.getUserId();
        if (userId != null) {
          // Parse duration from "MM:SS" format
          final parts = _timerText.split(':');
          final minutes = int.tryParse(parts[0]) ?? 0;
          final seconds = int.tryParse(parts[1]) ?? 0;
          final totalMinutes = minutes + (seconds > 0 ? 1 : 0); // Round up

          await ApiService().reportActivity(
            userId: userId,
            type: 'recording',
            minutes: totalMinutes > 0 ? totalMinutes : 1, // At least 1 minute
          );
          print('[STATS] Reported recording activity: $totalMinutes minutes');
        }
      } catch (e) {
        print('[STATS] Failed to report recording: $e');
      }

      // Navigate and wait for result to save again if modified
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => RecordingDetailsPage(recording: newRecording),
      ));
      await _saveRecordings();
    });
  }

  Future<void> _refreshRecordings() async {
    await _loadRecordings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Обновлено!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final subtextColor =
        isDarkMode ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);
    final cardColor =
        isDarkMode ? const Color(0xFF1f2937) : const Color(0xFFf3f4f6);
    final recordings = _filteredRecordings;
    final processedCount =
        _recordings.where((r) => r.summary?.isNotEmpty ?? false).length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshRecordings,
          color: const Color(0xFF6366F1),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    Text('AI-Диктофон',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 24),
                    _buildRecorderControls(cardColor, textColor, subtextColor),
                    const SizedBox(height: 24),
                    _buildStatsBar(textColor, subtextColor, processedCount),
                    const SizedBox(height: 16),
                    _buildSearchAndFilters(subtextColor),
                    const SizedBox(height: 24),
                    Text('История',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              if (_recordings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyRecordingsState(subtextColor),
                )
              else if (recordings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildNoResultsState(subtextColor),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final recording = recordings[index];
                        final isLast = index == recordings.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                          child: _buildRecordingTile(
                              recording, cardColor, textColor, subtextColor),
                        );
                      },
                      childCount: recordings.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(
      Color textColor, Color subtextColor, int processedCount) {
    final totalDurationSeconds = _recordings.fold<int>(0, (acc, rec) {
      final parts = rec.duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return acc + minutes * 60 + seconds;
      }
      return acc;
    });

    final totalDurationLabel =
        _formatTotalDuration(Duration(seconds: totalDurationSeconds));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
              LucideIcons.mic, '${_recordings.length}', 'записей', textColor),
          _buildStatItem(LucideIcons.sparkles, '$processedCount',
              'AI обработано', textColor),
          _buildStatItem(
              LucideIcons.timer, totalDurationLabel, 'минут аудио', textColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color textColor) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
      ],
    );
  }

  String _formatTotalDuration(Duration duration) {
    if (duration.inMinutes >= 60) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      if (minutes == 0) {
        return '$hours ч';
      }
      return '$hours ч $minutes м';
    }
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      return '$minutes м';
    }
    final seconds = duration.inSeconds;
    return '$seconds с';
  }

  Widget _buildSearchAndFilters(Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Поиск по записям',
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: subtextColor.withOpacity(0.2)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip('Все', RecordingFilter.all),
            _buildFilterChip('С AI-сводкой', RecordingFilter.aiReady),
            _buildFilterChip('Только оригиналы', RecordingFilter.raw),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, RecordingFilter filter) {
    final isActive = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => setState(() => _filter = filter),
      selectedColor: Colors.indigo,
      labelStyle: TextStyle(color: isActive ? Colors.white : null),
      backgroundColor: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildRecorderControls(
      Color cardColor, Color textColor, Color subtextColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecording ? Colors.indigo : cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _isRecording
              ? Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    Text(_timerText,
                        style: TextStyle(
                            color: _isRecording ? Colors.white : textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 16),
                    if (_isRecording)
                      WaveformAnimation(
                          animationController: _animationController!),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Новая запись',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    Text('Нажмите для начала',
                        style: TextStyle(color: subtextColor, fontSize: 14)),
                  ],
                ),
          ElevatedButton(
            onPressed: _toggleRecording,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
              backgroundColor: _isRecording ? Colors.red : Colors.indigo,
            ),
            child: Icon(_isRecording ? LucideIcons.stopCircle : LucideIcons.mic,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecordingsState(Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mic,
                size: 60, color: subtextColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('У вас пока нет записей',
                style: TextStyle(color: subtextColor, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Нажмите на микрофон для начала записи',
              style:
                  TextStyle(color: subtextColor.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX,
                size: 60, color: subtextColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Записей не найдено',
                style: TextStyle(color: subtextColor, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить фильтр или запрос поиска',
              style:
                  TextStyle(color: subtextColor.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingTile(Recording recording, Color cardColor,
      Color textColor, Color subtextColor) {
    return Dismissible(
      key: Key(recording.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1f2937),
            title: const Text('Удалить запись?',
                style: TextStyle(color: Colors.white)),
            content: Text(
              'Вы уверены, что хотите удалить "${recording.title}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        setState(() {
          _recordings.removeWhere((element) => element.id == recording.id);
        });
        await _saveRecordings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запись удалена'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => RecordingDetailsPage(recording: recording),
          ));
          await _saveRecordings();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: cardColor, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.fileAudio,
                    color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recording.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: subtextColor),
                        const SizedBox(width: 4),
                        Text(recording.duration,
                            style:
                                TextStyle(color: subtextColor, fontSize: 14)),
                        if ((recording.summary?.isNotEmpty ?? false) ||
                            (recording.transcription?.isNotEmpty ?? false)) ...[
                          const SizedBox(width: 12),
                          Icon(LucideIcons.sparkles,
                              size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text('AI',
                              style: TextStyle(
                                  color: Colors.indigo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveformAnimation extends AnimatedWidget {
  WaveformAnimation(
      {Key? key, required AnimationController animationController})
      : super(key: key, listenable: animationController);

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index.isEven ? _progress.value : (1 - _progress.value);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: 5.0 + value * 15.0,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
