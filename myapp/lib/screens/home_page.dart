import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/apk_downloader.dart';
import 'dart:convert';
import 'dart:async';

import 'scan_results_page.dart';
import 'scan_details_page.dart';
import 'scan_library_page.dart';
import 'create_set_page.dart';
import 'quiz_page.dart';
import '../models/study_set.dart';
import '../services/study_sets_service.dart';
import '../models/user_model.dart';
import '../models/update_info.dart';
import '../services/profile_notifier.dart';
import '../services/update_notifier.dart';
import '../services/update_service.dart';
import '../widgets/beta_badge.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final UpdateNotifier updateNotifier;
  const HomePage({
    super.key,
    this.onOpenProfile,
    required this.updateNotifier,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  final ProfileNotifier _profileNotifier = ProfileNotifier();
  UpdateStatus? _updateStatus;
  bool _serverReachable = true;
  String? _statusMessage;
  bool _isLaunchingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;
  final ApkDownloader _apkDownloader = ApkDownloader();
  StreamController<double>? _progressController;
  String? _lastSnackVersion;
  int _aiStreakCurrent = 0;
  int _totalScans = 0;
  int _totalRecordings = 0;
  int _studyMinutesToday = 0;
  int _totalScansToday = 0;
  int _totalRecordingsToday = 0;
  List<Map<String, dynamic>> _allScans = [];
  List<Map<String, dynamic>> _recentScans = [];

  UpdateInfo? get _availableUpdate => _updateStatus?.availableUpdate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStudyStatistics();
    _profileNotifier.addListener(_onProfileUpdated);
    widget.updateNotifier.addListener(_onUpdateStatusChanged);
    _syncUpdateStatus();
  }

  Widget _buildKeyFeaturesHeader(Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Продолжить обучение',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Три главные AI-инструмента, которые держат ваш прогресс на высоте',
          style: TextStyle(color: subtextColor),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _FeatureChip(label: 'AI Конспекты', icon: LucideIcons.scan),
            _FeatureChip(label: 'AI Диктофон', icon: LucideIcons.mic),
            _FeatureChip(
                label: 'AI Репетитор', icon: LucideIcons.messageSquare),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _profileNotifier.removeListener(_onProfileUpdated);
    widget.updateNotifier.removeListener(_onUpdateStatusChanged);
    _progressController?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateNotifier != widget.updateNotifier) {
      oldWidget.updateNotifier.removeListener(_onUpdateStatusChanged);
      widget.updateNotifier.addListener(_onUpdateStatusChanged);
      _syncUpdateStatus();
    }
  }

  void _onProfileUpdated() {
    if (mounted) {
      setState(() {
        _user = _profileNotifier.user;
      });
      _refreshAiDashboard();
    }
  }

  void _onUpdateStatusChanged() {
    _syncUpdateStatus();
  }

  void _syncUpdateStatus() {
    final status = widget.updateNotifier.status;
    final previousVersion = _updateStatus?.availableUpdate?.version;
    final newVersion = status?.availableUpdate?.version;
    final isPush = status?.viaPush == true;

    if (!mounted) return;
    setState(() {
      _updateStatus = status;
      _serverReachable = status?.serverReachable ?? true;
      _statusMessage = status?.message;
    });

    if (isPush && status?.availableUpdate != null) {
      final update = status!.availableUpdate!;
      final hasNewVersion = newVersion != null && newVersion != previousVersion;
      if (_lastSnackVersion != update.version || hasNewVersion) {
        _showUpdateSnack(update);
        _lastSnackVersion = update.version;
      }
    }
  }

  void _showUpdateSnack(UpdateInfo update) {
    if (!mounted) return;
    final snackBar = SnackBar(
      content: Text('Доступно обновление ${update.version}'),
      action: update.hasDownloadLink
          ? SnackBarAction(
              label: 'Скачать',
              onPressed: () => _launchUpdate(update.downloadUrl),
            )
          : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _loadUserData() async {
    final notifierUser = _profileNotifier.user;
    if (notifierUser != null) {
      setState(() => _user = notifierUser);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      final storedUser = User.fromSharedPreferences(userDataString);
      if (storedUser != null) {
        setState(() => _user = storedUser);
        _profileNotifier.updateUser(storedUser);
        _refreshAiDashboard();
      }
    }
  }

  Future<void> _refreshAiDashboard() async {
    final userId = _user?.id ?? await UserPrefs.getUserId();
    if (userId == null) return;
    try {
      final api = ApiService();
      final result = await api.getAiDashboard(userId);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final streak = data['streak'] as Map<String, dynamic>?;
        final current = streak != null
            ? (streak['current'] as int? ??
                int.tryParse('${streak['current']}') ??
                0)
            : 0;
        if (mounted) {
          setState(() => _aiStreakCurrent = current);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStudyStatistics() async {
    final userId = await UserPrefs.getUserId();
    if (userId == null) return;

    try {
      final api = ApiService();

      // Load saved scans
      final scansResult = await api.getScanNotes(userId);
      List<Map<String, dynamic>> parsedScans = [];
      if (scansResult['success'] == true) {
        final scans = scansResult['data'] as List<dynamic>?;
        if (scans != null) {
          parsedScans =
              scans.map((s) => Map<String, dynamic>.from(s as Map)).toList();
          setState(() {
            _totalScans = parsedScans.length;
            _allScans = List<Map<String, dynamic>>.from(parsedScans);
            _recentScans = parsedScans.take(3).toList();
          });
        }
      }

      // Load recordings count
      final recordingsResult = await api.getVoiceRecordings(userId);
      List<dynamic>? recordings;
      if (recordingsResult['success'] == true) {
        recordings = recordingsResult['data'] as List<dynamic>?;
        if (recordings != null) {
          setState(() {
            _totalRecordings = recordings!.length;
          });
        }
      }

      // Calculate real study time from today's activity
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      int todayScans = 0;
      int todayRecordings = 0;

      // Count today's scans
      if (parsedScans.isNotEmpty) {
        todayScans = parsedScans.where((scan) {
          try {
            final scanDate = DateTime.parse(scan['createdAt'].toString());
            return scanDate.isAfter(todayStart);
          } catch (_) {
            return false;
          }
        }).length;
      }

      // Count today's recordings
      if (recordings != null) {
        todayRecordings = recordings.where((rec) {
          try {
            final recDate = DateTime.parse(rec['createdAt'].toString());
            return recDate.isAfter(todayStart);
          } catch (_) {
            return false;
          }
        }).length;
      }

      // Calculate study time: 10 min per scan, 15 min per recording, + streak bonus
      setState(() {
        _studyMinutesToday =
            (todayScans * 10) + (todayRecordings * 15) + (_aiStreakCurrent * 5);
        _totalScansToday = todayScans;
        _totalRecordingsToday = todayRecordings;
      });
    } catch (e) {
      print('Error loading study statistics: $e');
    }
  }

  Future<void> _scanWithCamera() async {
    final ImagePicker picker = ImagePicker();
    // Pick an image from the camera with compression
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, // Сжимаем до 1024px (достаточно для AI анализа)
      maxHeight: 1024,
      imageQuality: 85, // Качество 85% - баланс между размером и качеством
    );

    if (image != null && mounted) {
      // Navigate to the results page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ScanResultsPage(image: image),
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
    // Улучшенные цвета для светлой темы
    final cardColor = isDarkMode ? const Color(0xFF1f2937) : Colors.white;
    final cardColor2 =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFF8FAFC);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshAiDashboard();
          await _loadStudyStatistics();
          print('[HomePage] Pull-to-refresh completed, streak updated');
        },
        color: const Color(0xFF6366F1),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildHeader(textColor),
              if (_availableUpdate != null) ...[
                const SizedBox(height: 16),
                _buildUpdateCard(textColor),
              ] else if (!_serverReachable) ...[
                const SizedBox(height: 16),
                _buildOfflineCard(textColor),
              ],
              const SizedBox(height: 24),
              _buildStatisticsSection(cardColor, textColor, subtextColor),
              const SizedBox(height: 24),
              _buildLearningSection(
                  cardColor, cardColor2, textColor, subtextColor),
              const SizedBox(height: 24),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              if (_recentScans.isNotEmpty) ...[
                _buildRecentScans(cardColor, textColor, subtextColor),
                const SizedBox(height: 24),
              ],
              _buildRecommendations(textColor, cardColor, subtextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard(Color textColor) {
    final update = _availableUpdate!;
    final isSnoozed = widget.updateNotifier.isSnoozed(update.version);
    String? publishedLabel;
    if (update.publishedAt != null) {
      final parsed = DateTime.tryParse(update.publishedAt!);
      if (parsed != null) {
        publishedLabel = _formatPublishedAt(parsed);
      }
    }

    if (isSnoozed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(LucideIcons.download,
                  color: Color(0xFF1D4ED8), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Доступно обновление ${update.version}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (publishedLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Опубликовано $publishedLabel',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!_isDownloading)
                ElevatedButton(
                  onPressed: update.hasDownloadLink && !_isLaunchingUpdate
                      ? () => _launchUpdate(update.downloadUrl)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    minimumSize: const Size(0, 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLaunchingUpdate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Скачать'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isDownloading && _progressController != null) ...[
            StreamBuilder<double>(
              stream: _progressController!.stream,
              initialData: 0.0,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Загрузка...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1D4ED8)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ],
          if (_downloadError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle,
                      color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _downloadError!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_isDownloading)
            GestureDetector(
              onTap: isSnoozed
                  ? null
                  : () async {
                      await widget.updateNotifier
                          .snooze(update.version, const Duration(minutes: 30));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Напоминание отключено на 30 минут')),
                        );
                      }
                      setState(() {});
                    },
              child: Text(
                isSnoozed
                    ? 'Напоминание временно отключено'
                    : 'Напомнить позже',
                style: TextStyle(
                  color: isSnoozed
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF1D4ED8),
                  decoration: isSnoozed
                      ? TextDecoration.none
                      : TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineCard(Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final description = _statusMessage ??
        'Не удалось проверить наличие обновлений. Проверьте подключение к интернету и повторите позже.';

    final backgroundColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF7ED);
    final borderColor =
        isDark ? Colors.white12 : const Color(0xFFF97316).withOpacity(0.2);
    final titleColor = isDark ? Colors.white : const Color(0xFF7C2D12);
    final iconColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFC2410C);
    final bodyColor = isDark ? Colors.white70 : textColor.withOpacity(0.85);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.wifiOff, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Нет соединения с сервером',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(color: bodyColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdate(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на обновление недоступна')),
      );
      return;
    }

    // Check if it's a server APK path
    if (url.startsWith('/apk/')) {
      await _downloadAndInstallApk(url);
    } else {
      // External URL - use browser
      final uri = Uri.tryParse(url);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Некорректная ссылка на обновление')),
        );
        return;
      }

      setState(() => _isLaunchingUpdate = true);
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Не удалось открыть ссылку на обновление')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при открытии ссылки: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLaunchingUpdate = false);
        }
      }
    }
  }

  Future<void> _downloadAndInstallApk(String path) async {
    // Close old controller if exists
    _progressController?.close();
    _progressController = StreamController<double>.broadcast();

    setState(() {
      _isLaunchingUpdate = true;
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      // Build full URL using ApiService base URL
      String serverUrl = ApiService.baseUrl;

      // Remove trailing slash if exists
      if (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }

      final fullUrl = '$serverUrl$path';
      print('[APK Download] Downloading from: $fullUrl');

      await _apkDownloader.downloadAndInstall(
        url: fullUrl,
        onProgress: (progress) {
          // Update via stream instead of setState to avoid UI lag
          _progressController?.add(progress);
          _downloadProgress = progress;
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обновление готово к установке'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      print('[APK Download] Error: $e');

      if (mounted) {
        String errorMessage = 'Ошибка скачивания';

        if (e.toString().contains('Connection refused') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage =
              'Не удалось подключиться к серверу. Проверьте настройки сервера.';
        } else if (e.toString().contains('404')) {
          errorMessage = 'APK файл не найден на сервере';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Превышено время ожидания';
        }

        setState(() {
          _isDownloading = false;
          _downloadError = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingUpdate = false);
      }
    }
  }

  String _formatPublishedAt(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _getGreetingByTime() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return 'Доброе утро';
    } else if (hour >= 12 && hour < 18) {
      return 'Добрый день';
    } else if (hour >= 18 && hour < 22) {
      return 'Добрый вечер';
    } else {
      return 'Доброй ночи';
    }
  }

  Widget _buildHeader(Color textColor) {
    final userName = _user?.name ?? 'Студент';
    final avatarText =
        _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : 'S';
    final greeting = _getGreetingByTime();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // AI Streak flame
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.flame,
                            size: 16, color: const Color(0xFFEA580C)),
                        const SizedBox(width: 4),
                        Text('$_aiStreakCurrent',
                            style: const TextStyle(
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if ((_user?.badges.isNotEmpty ?? false)) ...[
                    const SizedBox(width: 8),
                    UserBadges(
                      badges: _user!.badges,
                      iconSize: 18,
                      spacing: 6,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: widget.onOpenProfile,
          child: _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundImage: MemoryImage(
                    base64Decode(_user!.avatarUrl!.split(
                        ',')[1]), // Убираем data:image/jpeg;base64, префикс
                  ),
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(avatarText,
                      style: TextStyle(
                          fontSize: 20, color: Colors.indigo.shade800)),
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection(
      Color cardColor, Color textColor, Color subtextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            isDark ? null : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          else ...[
            const BoxShadow(
              color: Color(0x0F1F2937),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x051f2937),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Сегодняшняя статистика',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Icon(LucideIcons.trendingUp,
                  color: isDark ? Colors.white70 : const Color(0xFF6366F1),
                  size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: LucideIcons.clock,
                value: '$_studyMinutesToday',
                label: 'минут учебы',
                color: isDark ? Colors.white : textColor,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              _buildStatItem(
                icon: LucideIcons.bookOpen,
                value: '$_totalScansToday',
                label: 'конспектов',
                color: isDark ? Colors.white : textColor,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              _buildStatItem(
                icon: LucideIcons.mic2,
                value: '$_totalRecordingsToday',
                label: 'записей',
                color: isDark ? Colors.white : textColor,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool isDark = true,
  }) {
    return Column(
      children: [
        Icon(icon,
            color: isDark ? color.withOpacity(0.8) : const Color(0xFF6366F1),
            size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? color : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? color.withOpacity(0.8) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentScans(
      Color cardColor, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Недавние конспекты',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to scans library
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ScanDetailsPage()),
                );
              },
              child: Text(
                'Все',
                style: TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentScans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final scan = _recentScans[index];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x111F2937),
                            blurRadius: 12,
                            offset: Offset(0, 6),
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
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.fileText,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            scan['title'] ?? 'Конспект',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scan['summary'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 12, color: subtextColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatScanDate(scan['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatScanDate(dynamic dateStr) {
    try {
      if (dateStr == null) return 'Недавно';
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Сегодня';
      } else if (diff.inDays == 1) {
        return 'Вчера';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} дней назад';
      } else {
        return '${date.day}.${date.month.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return 'Недавно';
    }
  }

  Widget _buildLearningSection(
      Color cardColor, Color cardColor2, Color textColor, Color subtextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If no recent scans and no recordings, show motivational card
    if (_recentScans.isEmpty && _totalRecordings == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2E1065), const Color(0xFF5B21B6)]
                : [const Color(0xFFDDD6FE), const Color(0xFFC4B5FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Начните учиться!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF5B21B6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте свой первый конспект или запись лекции',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF6B21A8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ScanDetailsPage()),
                    ),
                    icon: Icon(LucideIcons.camera, size: 16),
                    label: Text('Сканировать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.graduationCap,
              size: 64,
              color: isDark
                  ? Colors.white24
                  : const Color(0xFF8B5CF6).withOpacity(0.3),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<StudySet?>(
      future: StudySetsService().getStudySets().then((sets) {
        return StudySetsService().getCurrentLearningSet();
      }),
      builder: (context, snapshot) {
        // Show last scan if no study set
        if (!snapshot.hasData && _recentScans.isNotEmpty) {
          final lastScan = _recentScans.first;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Продолжить обучение',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cardColor2,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text(
                      'Нет активных наборов',
                      style: TextStyle(color: subtextColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final studySet = snapshot.data!;
        final progressPercent = (studySet.progress * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Продолжить обучение',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizPage(setId: studySet.id),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cardColor2,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(studySet.icon, color: studySet.color, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(studySet.title,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text('Прогресс: $progressPercent%',
                                style: TextStyle(
                                    color: subtextColor, fontSize: 14)),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.playCircle,
                          color: Color(0xFF6366F1), size: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanDetailsPage()),
            );
          },
          child: _buildActionCard(
              LucideIcons.camera,
              'Скан',
              isDark ? const Color(0xFF1A2F1A) : const Color(0xFFDCFCE7),
              const Color(0xFF22C55E),
              isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateSetPage()),
            );
          },
          child: _buildActionCard(
              LucideIcons.plusCircle,
              'Создать',
              isDark ? const Color(0xFF1A2F1F) : const Color(0xFFD1FAE5),
              const Color(0xFF10B981),
              isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuizPage()),
            );
          },
          child: _buildActionCard(
              LucideIcons.swords,
              'Квиз',
              isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
              const Color(0xFF0EA5E9),
              isDark ? const Color(0xFF7DD3FC) : const Color(0xFF075985)),
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color bgColor,
      Color iconColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecommendations(
      Color textColor, Color cardColor, Color subtextColor) {
    return FutureBuilder<List<StudySet>>(
      future: StudySetsService().getStudySets(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKeyFeaturesHeader(textColor, subtextColor),
            const SizedBox(height: 16),
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Нет наборов',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создайте первый набор или сохраните конспект, чтобы запустить обучение.',
                      style: TextStyle(color: subtextColor),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildEmptyStateActions(),
                    ),
                  ],
                ),
              )
            else
              ...snapshot.data!.take(2).map((set) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizPage(setId: set.id),
                        ),
                      );
                    },
                    child: _buildSetCard(
                      cardColor,
                      subtextColor,
                      textColor,
                      set.title,
                      '${set.cards.length} карточек',
                      set.icon,
                      set.color,
                    ),
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSetCard(Color cardColor, Color subtextColor, Color textColor,
      String title, String subtitle, IconData icon, Color iconColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x111F2937),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x051F2937),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
                Text(subtitle, style: TextStyle(color: subtextColor)),
              ],
            ),
          ),
          Icon(LucideIcons.arrowDownCircle, color: subtextColor, size: 24),
        ],
      ),
    );
  }

  List<Widget> _buildEmptyStateActions() {
    return [
      _FeatureButton(
        label: 'Создать набор',
        icon: LucideIcons.plus,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateSetPage()),
          );
        },
      ),
      _FeatureButton(
        label: 'Перейти к конспектам',
        icon: LucideIcons.scan,
        onTap: () {
          if (_allScans.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Пока нет сохранённых конспектов')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanLibraryPage(
                  scans: List<Map<String, dynamic>>.from(_allScans)),
            ),
          );
        },
      ),
    ];
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FeatureChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE0E7FF);
    final textColor = isDark ? Colors.white : const Color(0xFF312E81);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
