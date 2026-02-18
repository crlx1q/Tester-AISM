import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/todo_task.dart';

class TodoTaskCard extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(int) onProgressChanged;

  const TodoTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = Color(TodoTask.getColorByPriority(task.priority));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: priorityColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: priorityColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя часть с чекбоксом и заголовком
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Чекбокс
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? priorityColor
                            : Colors.transparent,
                        border: Border.all(
                          color: priorityColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              LucideIcons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Контент
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        
                        // Описание
                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Метаинформация
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Приоритет
                            _buildChip(
                              icon: LucideIcons.flag,
                              label: TodoTask.getPriorityName(task.priority),
                              color: priorityColor,
                              isDark: isDark,
                            ),
                            
                            // Категория
                            if (task.category != null) ...[
                              _buildChip(
                                icon: LucideIcons.tag,
                                label: task.category!,
                                color: const Color(0xFF6366F1),
                                isDark: isDark,
                              ),
                            ],

                            // Дедлайн
                            if (task.deadline != null) ...[
                              _buildChip(
                                icon: LucideIcons.calendar,
                                label: _formatDeadline(task.deadline!),
                                color: task.isOverdue
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                isDark: isDark,
                                isOverdue: task.isOverdue,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Меню
                  PopupMenuButton<String>(
                    icon: Icon(
                      LucideIcons.moreVertical,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Удалить', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Прогресс-бар (если задача не завершена и прогресс > 0)
            if (!task.isCompleted && task.progress > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Прогресс',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${task.progress}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress / 100,
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Управление прогрессом
            if (!task.isCompleted) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildProgressButton(
                      context,
                      '0%',
                      0,
                      task.progress == 0,
                      isDark,
                    ),
                    _buildProgressButton(
                      context,
                      '25%',
                      25,
                      task.progress == 25,
                      isDark,
                    ),
                    _buildProgressButton(
                      context,
                      '50%',
                      50,
                      task.progress == 50,
                      isDark,
                    ),
                    _buildProgressButton(
                      context,
                      '75%',
                      75,
                      task.progress == 75,
                      isDark,
                    ),
                    _buildProgressButton(
                      context,
                      '100%',
                      100,
                      task.progress == 100,
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    bool isOverdue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(width: 4),
            const Text('⚠️', style: TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressButton(
    BuildContext context,
    String label,
    int progress,
    bool isSelected,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => onProgressChanged(progress),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : isDark
                  ? const Color(0xFF1F2937)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : isDark
                    ? Colors.grey[700]!
                    : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.grey[400]
                    : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference < 0) {
      return 'Просрочено ${-difference} дн.';
    } else if (difference == 0) {
      return 'Сегодня';
    } else if (difference == 1) {
      return 'Завтра';
    } else if (difference <= 7) {
      return 'Через $difference дн.';
    } else {
      return DateFormat('d MMM', 'ru_RU').format(deadline);
    }
  }
}

