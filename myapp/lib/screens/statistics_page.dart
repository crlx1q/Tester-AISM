import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/study_stats.dart';
import '../providers/stats_provider.dart';
import '../providers/quiz_provider.dart';
import '../services/profile_notifier.dart';
import '../services/achievements_service.dart';
import '../services/api_service.dart';

enum StatsPeriod { today, week, month }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatsPeriod _selectedPeriod = StatsPeriod.week;
  final ApiService _apiService = ApiService();
  final AchievementsService _achievementsService = AchievementsService();
  
  List<Map<String, dynamic>> _quizHistory = [];
  List<Map<String, dynamic>> _achievements = [];
  bool _isLoadingQuiz = false;
  bool _isLoadingAchievements = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user == null) return;

    _loadStats(user.id);
    _loadQuizHistory(user.id);
    _loadAchievements(user.id);
  }

  void _loadStats(int userId) {
    final provider = Provider.of<StatsProvider>(context, listen: false);
    switch (_selectedPeriod) {
      case StatsPeriod.today:
        provider.loadTodayStats(userId, forceRefresh: true);
        break;
      case StatsPeriod.week:
        provider.loadWeekStats(userId, forceRefresh: true);
        break;
      case StatsPeriod.month:
        provider.loadMonthStats(userId, forceRefresh: true);
        break;
    }
  }

  Future<void> _loadQuizHistory(int userId) async {
    setState(() => _isLoadingQuiz = true);
    try {
      final result = await _apiService.getQuizHistory(userId, limit: 50);
      print('[Statistics] Quiz history result: ${result.toString().substring(0, result.toString().length > 500 ? 500 : result.toString().length)}');
      if (result['success'] == true) {
        // Проверяем разные форматы ответа
        List<Map<String, dynamic>> history = [];
        if (result['data'] != null) {
          if (result['data'] is List) {
            // Прямой массив (как возвращает сервер)
            history = (result['data'] as List).map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              }
              return Map<String, dynamic>.from(item as Map);
            }).toList();
          } else if (result['data'] is Map) {
            // Объект с данными
            final dataMap = result['data'] as Map<String, dynamic>;
            if (dataMap['data'] is List) {
              history = (dataMap['data'] as List).map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                }
                return Map<String, dynamic>.from(item as Map);
              }).toList();
            } else if (dataMap['results'] is List) {
              history = (dataMap['results'] as List).map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                }
                return Map<String, dynamic>.from(item as Map);
              }).toList();
            }
          }
        }
        print('[Statistics] Loaded ${history.length} quiz results');
        if (history.isNotEmpty) {
          print('[Statistics] First quiz ID: ${history[0]['id']}, Score: ${history[0]['score']}, Title: ${history[0]['setTitle']}');
        }
        setState(() {
          _quizHistory = history;
        });
      } else {
        print('[Statistics] Failed to load quiz history: ${result['message']}');
        setState(() {
          _quizHistory = [];
        });
      }
    } catch (e) {
      print('[Statistics] Error loading quiz history: $e');
      setState(() {
        _quizHistory = [];
      });
    } finally {
      setState(() => _isLoadingQuiz = false);
    }
  }

  Future<void> _loadAchievements(int userId) async {
    setState(() => _isLoadingAchievements = true);
    try {
      final achievements = await _achievementsService.getAllAchievements();
      setState(() {
        _achievements = achievements
            .where((a) => a.isUnlocked)
            .map((a) => {
                  'id': a.id,
                  'name': a.name,
                  'description': a.description,
                  'unlockedAt': a.unlockedAt,
                })
            .toList();
      });
    } catch (e) {
      print('[Statistics] Error loading achievements: $e');
    } finally {
      setState(() => _isLoadingAchievements = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
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
          'Статистика',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _buildPeriodSelector(cardColor, textColor, subtextColor ?? Colors.grey[600]!),
            const SizedBox(height: 24),

            // Study time chart
            _buildStudyTimeChart(cardColor, textColor, subtextColor ?? Colors.grey[600]!, isDark),
            const SizedBox(height: 24),

            // Activity breakdown
            _buildActivityBreakdown(cardColor, textColor, subtextColor ?? Colors.grey[600]!, isDark),
            const SizedBox(height: 24),

            // Quiz statistics
            _buildQuizStatistics(cardColor, textColor, subtextColor ?? Colors.grey[600]!, isDark),
            const SizedBox(height: 24),

            // Achievements progress
            _buildAchievementsProgress(cardColor, textColor, subtextColor ?? Colors.grey[600]!, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearStatsDialog(BuildContext context, Color textColor, Color subtextColor, Color cardColor, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Очистить статистику?',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          'Это действие удалит всю статистику из базы данных:\n\n'
          '• Время обучения\n'
          '• История квизов\n'
          '• Прогресс по темам\n'
          '• Стрик будет сброшен\n\n'
          'Это действие нельзя отменить!',
          style: TextStyle(color: subtextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearAllStats();
    }
  }

  Future<void> _clearAllStats() async {
    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1F2937) 
            : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Очистка статистики...',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await _apiService.clearAllStats(user.id);
      if (mounted) {
        Navigator.pop(context); // Закрыть диалог загрузки
        
        if (result['success'] == true) {
          // Очистить локальный кэш
          final provider = Provider.of<StatsProvider>(context, listen: false);
          provider.clearCache();
          
          // Перезагрузить данные
          _loadData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Статистика успешно очищена'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: ${result['message'] ?? 'Не удалось очистить статистику'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрыть диалог загрузки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка очистки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPeriodSelector(Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('День', StatsPeriod.today, textColor, subtextColor),
          ),
          Expanded(
            child: _buildPeriodButton('Неделя', StatsPeriod.week, textColor, subtextColor),
          ),
          Expanded(
            child: _buildPeriodButton('Месяц', StatsPeriod.month, textColor, subtextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, StatsPeriod period, Color textColor, Color subtextColor) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : subtextColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStudyTimeChart(Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Consumer<StatsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // DAY VIEW: агрегированная карточка без графика
        if (_selectedPeriod == StatsPeriod.today) {
          final today = provider.todayStats;
          if (today == null) {
            return _buildEmptyCard(cardColor, textColor, 'Нет данных за сегодня');
          }

          String _formatMinutes(int minutes) {
            if (minutes <= 0) return '0 мин';
            final h = minutes ~/ 60;
            final m = minutes % 60;
            if (h > 0) return '${h}ч ${m}м';
            return '${m}м';
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Время обучения сегодня',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatMinutes(today.studyMinutes),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Активности',
                        '${today.totalActivities}',
                        LucideIcons.activity,
                        Colors.indigo,
                        textColor,
                        subtextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Квизы',
                        '${today.quizzesTaken}',
                        LucideIcons.swords,
                        Colors.blue,
                        textColor,
                        subtextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Конспекты',
                        '${today.scansCount}',
                        LucideIcons.scan,
                        Colors.green,
                        textColor,
                        subtextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Записи',
                        '${today.recordingsCount}',
                        LucideIcons.mic,
                        Colors.purple,
                        textColor,
                        subtextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Чат',
                        '${today.chatSessionsCount}',
                        LucideIcons.messageSquare,
                        Colors.orange,
                        textColor,
                        subtextColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Карточки',
                        '${today.cardsCreated}',
                        LucideIcons.layers,
                        Colors.teal,
                        textColor,
                        subtextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // WEEK / MONTH: график
        StudyStatsWeek? stats;
        if (_selectedPeriod == StatsPeriod.week) {
          stats = provider.weekStats;
        } else if (_selectedPeriod == StatsPeriod.month) {
          stats = provider.weekStats; // Используем weekStats для месяца (он содержит месячные данные через loadMonthStats)
        }

        if (stats == null || stats.dailyStats.isEmpty) {
          return _buildEmptyCard(cardColor, textColor, 'Нет данных о времени обучения');
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Время обучения',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${stats.totalStudyMinutes} мин',
                      style: TextStyle(
                        color: const Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: cardColor,
                        tooltipRoundedRadius: 8,
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _calculateInterval(stats.dailyStats.map((d) => d.studyMinutes.toDouble()).toList()),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < stats!.dailyStats.length) {
                              final date = stats.dailyStats[value.toInt()].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('dd.MM').format(date),
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 10,
                              ),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: stats.dailyStats.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.studyMinutes.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFF6366F1),
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: const Color(0xFF6366F1),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                        ),
                      ),
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

  double _calculateInterval(List<double> values) {
    if (values.isEmpty) return 10;
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max == 0) return 10;
    return (max / 5).ceilToDouble();
  }

  Widget _buildActivityBreakdown(Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Consumer<StatsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        // DAY VIEW: простой числовой список без прогресс-баров
        if (_selectedPeriod == StatsPeriod.today) {
          final s = provider.todayStats;
          if (s == null) {
            return _buildEmptyCard(cardColor, textColor, 'Нет данных об активности');
          }
          final items = [
            {'icon': LucideIcons.scan, 'label': 'Сканы', 'count': s.scansCount, 'color': Colors.green},
            {'icon': LucideIcons.mic, 'label': 'Записи', 'count': s.recordingsCount, 'color': Colors.purple},
            {'icon': LucideIcons.messageSquare, 'label': 'Чат', 'count': s.chatSessionsCount, 'color': Colors.orange},
            {'icon': LucideIcons.swords, 'label': 'Квизы', 'count': s.quizzesTaken, 'color': Colors.blue},
            {'icon': LucideIcons.layers, 'label': 'Карточки созданы', 'count': s.cardsCreated, 'color': Colors.teal},
          ];

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Активность сегодня',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...items.map((activity) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (activity['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: activity['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activity['label'] as String,
                            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${activity['count']}',
                          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }

        // WEEK / MONTH: относительные полосы
        StudyStatsWeek? stats;
        if (_selectedPeriod == StatsPeriod.week) {
          stats = provider.weekStats;
        } else if (_selectedPeriod == StatsPeriod.month) {
          stats = provider.weekStats;
        }

        if (stats == null) {
          return _buildEmptyCard(cardColor, textColor, 'Нет данных об активности');
        }

        final activities = [
          {'icon': LucideIcons.scan, 'label': 'Сканы', 'count': stats.totalScans, 'color': Colors.green},
          {'icon': LucideIcons.mic, 'label': 'Записи', 'count': stats.totalRecordings, 'color': Colors.purple},
          {'icon': LucideIcons.messageSquare, 'label': 'Чат', 'count': stats.totalChatSessions, 'color': Colors.orange},
          {'icon': LucideIcons.swords, 'label': 'Квизы', 'count': stats.totalQuizzes, 'color': Colors.blue},
        ];

        final maxCount = activities.map((a) => a['count'] as int).reduce((a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Активность',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              ...activities.map((activity) {
                final progress = maxCount > 0 ? (activity['count'] as int) / maxCount : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (activity['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          activity['icon'] as IconData,
                          color: activity['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  activity['label'] as String,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${activity['count']}',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activity['color'] as Color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuizStatistics(Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    if (_isLoadingQuiz) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizHistory.isEmpty) {
      return _buildEmptyCard(cardColor, textColor, 'Нет данных о квизах');
    }

    final totalQuizzes = _quizHistory.length;
    final avgScore = _quizHistory.map((q) => q['score'] ?? 0).reduce((a, b) => a + b) / totalQuizzes;
    final perfectScores = _quizHistory.where((q) => q['score'] == 100).length;
    final recentQuizzes = _quizHistory.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика квизов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Всего квизов',
                  '$totalQuizzes',
                  LucideIcons.swords,
                  Colors.blue,
                  textColor,
                  subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Средний балл',
                  '${avgScore.toStringAsFixed(0)}%',
                  LucideIcons.trendingUp,
                  Colors.green,
                  textColor,
                  subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Идеально',
                  '$perfectScores',
                  LucideIcons.star,
                  Colors.amber,
                  textColor,
                  subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Последние квизы',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...recentQuizzes.map((quiz) {
            // Парсим дату из разных форматов
            DateTime? date;
            try {
              if (quiz['createdAt'] != null) {
                if (quiz['createdAt'] is String) {
                  date = DateTime.parse(quiz['createdAt']);
                } else if (quiz['createdAt'] is Map) {
                  final dateMap = quiz['createdAt'] as Map;
                  if (dateMap['\$date'] != null) {
                    date = DateTime.fromMillisecondsSinceEpoch(dateMap['\$date'] as int);
                  }
                }
              }
            } catch (e) {
              print('[Statistics] Error parsing date: $e');
            }
            date ??= DateTime.now();
            
            final score = quiz['score'] is int ? quiz['score'] : (quiz['score'] is double ? (quiz['score'] as double).round() : 0);
            final title = quiz['setTitle']?.toString() ?? quiz['setId']?.toString() ?? 'Неизвестный набор';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd.MM.yyyy').format(date),
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getScoreColor(score).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$score%',
                      style: TextStyle(
                        color: _getScoreColor(score),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color,
      Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: subtextColor,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsProgress(Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    if (_isLoadingAchievements) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List>(
      future: _achievementsService.getAllAchievements(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final achievements = snapshot.data!;
        final unlockedCount = achievements.where((a) => a.isUnlocked).length;
        final totalCount = achievements.length;
        final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Достижения',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '$unlockedCount / $totalCount',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_achievements.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _achievements.take(6).map((ach) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ach['name'] ?? '',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard(Color cardColor, Color textColor, String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

