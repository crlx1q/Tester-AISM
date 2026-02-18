import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../widgets/hero_section.dart';
import '../widgets/ai_tasks_widget.dart';
import '../widgets/recent_materials_carousel.dart';
import '../widgets/stats_card.dart';
import '../widgets/insights_preview_card.dart';
import '../providers/planner_provider.dart';
import '../providers/notebook_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/insights_provider.dart';
import '../services/profile_notifier.dart';
import '../services/update_notifier.dart';
import '../services/apk_downloader.dart';
import '../services/api_service.dart';
import '../models/study_set.dart';
import '../services/study_sets_service.dart';
import 'scanner_page.dart';
import 'recorder_page.dart';
import 'tutor_page.dart';
import 'study_planner_page.dart';
import 'ai_notebook_page.dart';
import 'ai_insights_page.dart';
import 'quiz_page.dart';
import 'create_set_page_guided.dart';
import 'focus_page.dart';

class HomePageNew extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenRecorder;
  final VoidCallback? onOpenTutor;
  final UpdateNotifier updateNotifier;

  const HomePageNew({
    Key? key,
    this.onOpenProfile,
    this.onOpenRecorder,
    this.onOpenTutor,
    required this.updateNotifier,
  }) : super(key: key);

  @override
  State<HomePageNew> createState() => _HomePageNewState();
}

class _HomePageNewState extends State<HomePageNew> {
  List<StudySet> _studySets = [];
  bool _isLoadingSets = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _downloadAndInstallUpdate(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Build full URL if path is relative
      String fullUrl = url;
      if (url.startsWith('/')) {
        String serverUrl = ApiService.baseUrl;

        // Remove trailing slash if exists
        if (serverUrl.endsWith('/')) {
          serverUrl = serverUrl.substring(0, serverUrl.length - 1);
        }

        fullUrl = '$serverUrl$url';
      }

      print('[APK Download] Downloading from: $fullUrl');

      final downloader = ApkDownloader();
      await downloader.downloadAndInstall(
        url: fullUrl,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (mounted) {
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
        String errorMessage = 'Ошибка загрузки';

        if (e.toString().contains('Connection refused') ||
            e.toString().contains('Failed host lookup')) {
          errorMessage =
              'Не удалось подключиться к серверу. Проверьте настройки сервера.';
        } else if (e.toString().contains('404')) {
          errorMessage = 'APK файл не найден на сервере';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Превышено время ожидания';
        } else {
          errorMessage = 'Ошибка загрузки: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final profileNotifier =
        Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;

    if (user != null) {
      // Load all providers with force refresh
      await Future.wait([
        Provider.of<StatsProvider>(context, listen: false)
            .loadTodayStats(user.id, forceRefresh: true),
        Provider.of<NotebookProvider>(context, listen: false)
            .loadEntries(user.id, forceRefresh: true),
        Provider.of<PlannerProvider>(context, listen: false)
            .loadSchedule(user.id, forceRefresh: true),
        Provider.of<InsightsProvider>(context, listen: false)
            .loadLatestInsight(user.id, forceRefresh: true),
      ]);
    }

    // Load study sets
    await _loadStudySets();

    // Обновляем streak в HeroSection
    heroSectionKey.currentState?.reloadStreak();
    print('[HomePage] Streak reloaded on pull-to-refresh');
  }

  Future<void> _loadStudySets() async {
    try {
      final sets = await StudySetsService().getStudySets();
      setState(() {
        _studySets = sets;
        _isLoadingSets = false;
      });
    } catch (e) {
      setState(() => _isLoadingSets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF6366F1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar
                  _buildAppBar(textColor),

                  const SizedBox(height: 16),

                  // Update Banner (if available)
                  AnimatedBuilder(
                    animation: widget.updateNotifier,
                    builder: (context, child) {
                      final status = widget.updateNotifier.status;
                      if (status == null) return const SizedBox.shrink();
                      final update = status.availableUpdate;
                      if (update == null) return const SizedBox.shrink();
                      if (widget.updateNotifier.isSnoozed(update.version)) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
                                    const Icon(LucideIcons.download,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Доступно обновление!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.x,
                                          color: Colors.white, size: 20),
                                      onPressed: () {
                                        widget.updateNotifier.snooze(
                                          update.version,
                                          const Duration(hours: 24),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Версия ${update.version}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                                if (update.message.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    update.message,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _isDownloading
                                    ? Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Загрузка...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: _downloadProgress,
                                              backgroundColor:
                                                  Colors.white.withOpacity(0.3),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(Colors.white),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: update.hasDownloadLink
                                              ? () => _downloadAndInstallUpdate(
                                                  update.downloadUrl)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                const Color(0xFF3B82F6),
                                          ),
                                          icon: const Icon(LucideIcons.download,
                                              size: 18),
                                          label: const Text('Обновить сейчас'),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),

                  // 1. Hero Section
                  HeroSection(
                    key: heroSectionKey,
                    onScanTap: () => _openScanner(),
                    onRecordTap: widget.onOpenRecorder ?? _openRecorder,
                    onChatTap: widget.onOpenTutor ?? _openTutor,
                  ),

                  const SizedBox(height: 24),

                  // 2. AI Tasks (Today)
                  AiTasksWidget(
                    onViewAll: () => _navigateTo(const StudyPlannerPage()),
                  ),

                  const SizedBox(height: 24),

                  // 3. Recent Materials from AI Notebook
                  RecentMaterialsCarousel(),

                  const SizedBox(height: 24),

                  // 4. Study Statistics
                  StatsCard(),

                  const SizedBox(height: 24),

                  // 5. AI Insights of the Week (только для PRO)
                  Consumer<ProfileNotifier>(
                    builder: (context, notifier, child) {
                      final user = notifier.user;
                      final isPro = user?.pro?.status == true;
                      
                      if (!isPro) {
                        return const SizedBox.shrink(); // Не показываем блок для бесплатных пользователей
                      }
                      
                      return Column(
                        children: [
                          InsightsPreviewCard(
                            onViewAll: () => _navigateTo(const AiInsightsPage()),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // 6. Your Study Sets
                  _buildStudySetsSection(textColor, subtextColor),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateTo(const AiNotebookPage()),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(LucideIcons.bookOpen, color: Colors.white),
        label: const Text(
          'AI Notebook',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAppBar(Color textColor) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    Color iconColor;

    if (hour >= 0 && hour < 6) {
      greeting = 'Доброй ночи!';
      greetingIcon = LucideIcons.moon;
      iconColor = Colors.indigo;
    } else if (hour >= 6 && hour < 12) {
      greeting = 'Доброе утро!';
      greetingIcon = LucideIcons.sunrise;
      iconColor = Colors.orange;
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Добрый день!';
      greetingIcon = LucideIcons.sun;
      iconColor = Colors.amber;
    } else {
      greeting = 'Добрый вечер!';
      greetingIcon = LucideIcons.moon;
      iconColor = Colors.indigo;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    greetingIcon,
                    color: iconColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Consumer<ProfileNotifier>(
                builder: (context, notifier, child) {
                  final user = notifier.user;
                  final isPro = user?.pro?.status == true;

                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.name ?? 'Студент',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.crown,
                                color: Colors.black,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Кнопка фокуса
            GestureDetector(
              onTap: () => _openFocus(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.timer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Аватар
            GestureDetector(
              onTap: widget.onOpenProfile,
              child: Consumer<ProfileNotifier>(
                builder: (context, notifier, child) {
                  final user = notifier.user;

                  // Decode avatar once and cache it
                  Widget avatarWidget;
                  if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
                    try {
                      final imageData = base64Decode(
                          user.avatarUrl!.contains(',')
                              ? user.avatarUrl!.split(',')[1]
                              : user.avatarUrl!);
                      avatarWidget = ClipOval(
                        child: Image.memory(
                          imageData,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          gaplessPlayback: true, // Prevents flickering
                          errorBuilder: (_, __, ___) => const Icon(
                            LucideIcons.user,
                            color: Color(0xFF6366F1),
                            size: 24,
                          ),
                        ),
                      );
                    } catch (e) {
                      avatarWidget = const Icon(
                        LucideIcons.user,
                        color: Color(0xFF6366F1),
                        size: 24,
                      );
                    }
                  } else {
                    avatarWidget = const Icon(
                      LucideIcons.user,
                      color: Color(0xFF6366F1),
                      size: 24,
                    );
                  }

                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      border: Border.all(
                        color: const Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    child: avatarWidget,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudySetsSection(Color textColor, Color? subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ваши наборы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton.icon(
              onPressed: () => _navigateToCreateSet(),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Создать'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSets)
          const Center(child: CircularProgressIndicator())
        else if (_studySets.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    LucideIcons.layers,
                    color: subtextColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Нет учебных наборов',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте свой первый набор карточек',
                    style: TextStyle(color: subtextColor),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75, // Увеличена высота карточек для тегов
            ),
            itemCount: _studySets.length,
            itemBuilder: (context, index) {
              final set = _studySets[index];
              return Dismissible(
                key: Key(set.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Удалить набор?'),
                          content: Text(
                              'Вы уверены что хотите удалить "${set.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Удалить',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (direction) async {
                  // Remove from local storage
                  await StudySetsService().deleteStudySet(set.id);

                  // Reload all sets to refresh the list
                  if (mounted) {
                    await _loadStudySets();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Набор "${set.title}" удалён'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.trash2,
                      color: Colors.red, size: 28),
                ),
                child: _buildSetCard(set, textColor, subtextColor),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSetCard(StudySet set, Color textColor, Color? subtextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return GestureDetector(
      onTap: () => _navigateTo(QuizPage(setId: set.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: set.color.withOpacity(0.3),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: set.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(set.icon, color: set.color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              set.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(LucideIcons.layers, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text(
                  '${set.cards.length} карточек',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
            if (set.tags.isNotEmpty || set.course != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (set.course != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: set.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        set.course!,
                        style: TextStyle(
                          fontSize: 10,
                          color: set.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...set.tags.take(2).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: subtextColor?.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            color: subtextColor,
                          ),
                        ),
                      )),
                  if (set.tags.length > 2)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: subtextColor?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+${set.tags.length - 2}',
                        style: TextStyle(
                          fontSize: 10,
                          color: subtextColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
  }

  void _openRecorder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecorderPage()),
    );
  }

  void _openTutor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorPage()),
    );
  }

  void _openFocus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FocusPage()),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _navigateToCreateSet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateSetPageGuided()),
    );

    // Refresh study sets if a new set was created
    if (result == true && mounted) {
      await _loadStudySets();
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
}
