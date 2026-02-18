import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/study_stats.dart';
import '../providers/stats_provider.dart';
import '../services/profile_notifier.dart';
import '../screens/statistics_page.dart';

class StatsCard extends StatefulWidget {
  const StatsCard({Key? key}) : super(key: key);

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard> {
  bool _showWeek = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  void _loadStats() {
    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user != null) {
      final provider = Provider.of<StatsProvider>(context, listen: false);
      if (_showWeek) {
        provider.loadWeekStats(user.id);
      } else {
        provider.loadTodayStats(user.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Статистика',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildToggleButton('Сегодня', !_showWeek, textColor),
                        _buildToggleButton('Неделя', _showWeek, textColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(LucideIcons.arrowRight, color: textColor, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsPage(),
                        ),
                      );
                    },
                    tooltip: 'Подробная статистика',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          Consumer<StatsProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_showWeek) {
                return _buildWeekStats(provider.weekStats, textColor, subtextColor);
              } else {
                return _buildTodayStats(provider.todayStats, textColor, subtextColor);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool selected, Color textColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showWeek = label == 'Неделя';
        });
        _loadStats();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : textColor.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStats(StudyStatsDaily? stats, Color textColor, Color? subtextColor) {
    if (stats == null) {
      return _buildEmptyState(subtextColor);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                LucideIcons.clock,
                '${stats.studyMinutes}',
                'минут',
                Colors.blue,
                textColor,
                subtextColor,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                LucideIcons.scan,
                '${stats.scansCount}',
                'сканов',
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
              child: _buildStatItem(
                LucideIcons.mic,
                '${stats.recordingsCount}',
                'записей',
                Colors.purple,
                textColor,
                subtextColor,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                LucideIcons.messageSquare,
                '${stats.chatSessionsCount}',
                'сессий',
                Colors.orange,
                textColor,
                subtextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekStats(StudyStatsWeek? stats, Color textColor, Color? subtextColor) {
    if (stats == null || stats.dailyStats.isEmpty) {
      return _buildEmptyState(subtextColor);
    }

    return Column(
      children: [
        // Total summary
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                LucideIcons.clock,
                '${stats.totalStudyMinutes}',
                'минут',
                Colors.blue,
                textColor,
                subtextColor,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                LucideIcons.activity,
                '${stats.totalActivities}',
                'активностей',
                Colors.green,
                textColor,
                subtextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Chart
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: stats.dailyStats.map((d) => d.studyMinutes.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                      if (value.toInt() >= 0 && value.toInt() < days.length) {
                        return Text(
                          days[value.toInt()],
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 10,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: stats.dailyStats.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.studyMinutes.toDouble(),
                      color: const Color(0xFF6366F1),
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
    Color textColor,
    Color? subtextColor,
  ) {
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color? subtextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          'Нет данных',
          style: TextStyle(
            color: subtextColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

