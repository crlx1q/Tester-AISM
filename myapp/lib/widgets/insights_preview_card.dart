import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/insights_provider.dart';

class InsightsPreviewCard extends StatelessWidget {
  final VoidCallback? onViewAll;

  const InsightsPreviewCard({Key? key, this.onViewAll}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.1),
            const Color(0xFF8B5CF6).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Consumer<InsightsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final insight = provider.latestInsight;

          if (insight == null) {
            return Column(
              children: [
                Icon(
                  LucideIcons.sparkles,
                  color: const Color(0xFF6366F1),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'AI Insights недели',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Пока недостаточно данных для анализа',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        color: const Color(0xFF6366F1),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onViewAll != null)
                    GestureDetector(
                      onTap: onViewAll,
                      child: Text(
                        'Подробнее',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                insight.weekLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 16),
              if (insight.summary.isNotEmpty)
                Text(
                  insight.summary,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      LucideIcons.clock,
                      '${insight.stats.totalStudyMinutes}',
                      'минут',
                      Colors.blue,
                      textColor,
                      subtextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      LucideIcons.trophy,
                      '${insight.stats.averageScore}%',
                      'средний',
                      Colors.orange,
                      textColor,
                      subtextColor,
                    ),
                  ),
                ],
              ),
              if (insight.learnedTopics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: insight.learnedTopics.take(3).map((topic) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox(
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }
}

