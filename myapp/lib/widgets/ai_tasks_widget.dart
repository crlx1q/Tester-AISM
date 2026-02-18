import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/planner_schedule.dart';
import '../providers/planner_provider.dart';
import '../services/profile_notifier.dart';

class AiTasksWidget extends StatefulWidget {
  final VoidCallback? onViewAll;

  const AiTasksWidget({Key? key, this.onViewAll}) : super(key: key);

  @override
  State<AiTasksWidget> createState() => _AiTasksWidgetState();
}

class _AiTasksWidgetState extends State<AiTasksWidget> {
  String? _togglingTaskId;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Задачи на сегодня',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  // Refresh button
                  Consumer<PlannerProvider>(
                    builder: (context, provider, child) {
                      return GestureDetector(
                        onTap: provider.isLoading
                            ? null
                            : () async {
                                final profileNotifier =
                                    Provider.of<ProfileNotifier>(context,
                                        listen: false);
                                final user = profileNotifier.user;
                                if (user != null) {
                                  await provider.loadSchedule(user.id,
                                      forceRefresh: true);
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: provider.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF6366F1)),
                                  ),
                                )
                              : Icon(
                                  LucideIcons.refreshCw,
                                  size: 18,
                                  color: const Color(0xFF6366F1),
                                ),
                        ),
                      );
                    },
                  ),
                  if (widget.onViewAll != null)
                    GestureDetector(
                      onTap: widget.onViewAll,
                      child: Text(
                        'Все',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<PlannerProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.schedule == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                    ),
                  ),
                );
              }

              final tasks = provider.getTodayTasks().take(5).toList();

              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.checkCircle2,
                          color: subtextColor,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Нет задач на сегодня',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: tasks.map((task) {
                  return _buildTaskItem(
                    task,
                    textColor,
                    subtextColor,
                    provider,
                    context,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    PlannerTask task,
    Color textColor,
    Color? subtextColor,
    PlannerProvider provider,
    BuildContext context,
  ) {
    IconData icon;
    Color iconColor;

    switch (task.type) {
      case TaskType.reviewLecture:
        icon = LucideIcons.mic;
        iconColor = Colors.blue;
        break;
      case TaskType.reviewScan:
        icon = LucideIcons.scan;
        iconColor = Colors.green;
        break;
      case TaskType.quiz:
        icon = LucideIcons.checkCircle2;
        iconColor = Colors.purple;
        break;
      case TaskType.reading:
        icon = LucideIcons.book;
        iconColor = Colors.orange;
        break;
      case TaskType.custom:
        icon = LucideIcons.target;
        iconColor = Colors.grey;
        break;
    }

    final priorityColor = task.priority == TaskPriority.high
        ? Colors.red
        : task.priority == TaskPriority.medium
            ? Colors.orange
            : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_togglingTaskId == task.id) return;

              setState(() {
                _togglingTaskId = task.id;
              });

              final profileNotifier =
                  Provider.of<ProfileNotifier>(context, listen: false);
              final user = profileNotifier.user;
              if (user != null) {
                await provider.toggleTask(task.id, user.id);
                await provider.loadSchedule(user.id, forceRefresh: true);
              }

              if (mounted) {
                setState(() {
                  _togglingTaskId = null;
                });
              }
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.completed ? Colors.green : priorityColor,
                  width: 2,
                ),
                color: task.completed ? Colors.green : Colors.transparent,
              ),
              child: _togglingTaskId == task.id
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : task.completed
                      ? const Icon(LucideIcons.check,
                          size: 12, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(task.completed ? 0.05 : 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: task.completed ? iconColor.withOpacity(0.4) : iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        task.completed ? textColor.withOpacity(0.5) : textColor,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                    decorationColor:
                        task.completed ? textColor.withOpacity(0.5) : null,
                    decorationThickness: 2.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.dueTime != null)
                  Text(
                    task.dueTime!,
                    style: TextStyle(
                      fontSize: 12,
                      color: task.completed
                          ? subtextColor?.withOpacity(0.4)
                          : subtextColor,
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null,
                      decorationColor: task.completed
                          ? subtextColor?.withOpacity(0.4)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          if (task.priority == TaskPriority.high)
            Icon(LucideIcons.flag, color: Colors.red, size: 14),
        ],
      ),
    );
  }
}
