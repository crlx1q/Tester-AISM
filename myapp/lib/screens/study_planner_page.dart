import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/planner_schedule.dart';
import '../providers/planner_provider.dart';
import '../services/profile_notifier.dart';

class StudyPlannerPage extends StatefulWidget {
  const StudyPlannerPage({Key? key}) : super(key: key);

  @override
  State<StudyPlannerPage> createState() => _StudyPlannerPageState();
}

class _StudyPlannerPageState extends State<StudyPlannerPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _togglingTaskId; // ID задачи которая переключается
  bool _isAddingTask = false; // Флаг добавления задачи
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlanner();
    });
  }

  void _loadPlanner() {
    final profileNotifier =
        Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user != null) {
      Provider.of<PlannerProvider>(context, listen: false)
          .loadSchedule(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
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
          'План обучения',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.sparkles, color: textColor),
            onPressed: () => _generatePlan(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
            child: Consumer<PlannerProvider>(
              builder: (context, provider, child) {
                return TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  locale: 'ru_RU',
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  // Add event markers
                  eventLoader: (day) {
                    final tasksForDay = provider.getTasksForDate(day);
                    return List.generate(tasksForDay.length, (index) => '•');
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    defaultTextStyle: TextStyle(color: textColor),
                    weekendTextStyle: TextStyle(color: textColor),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon:
                        Icon(LucideIcons.chevronLeft, color: textColor),
                    rightChevronIcon:
                        Icon(LucideIcons.chevronRight, color: textColor),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: subtextColor),
                    weekendStyle: TextStyle(color: subtextColor),
                  ),
                );
              },
            ),
          ),

          // Tasks for selected day
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay.day == DateTime.now().day &&
                          _selectedDay.month == DateTime.now().month &&
                          _selectedDay.year == DateTime.now().year
                      ? 'Сегодня'
                      : DateFormat('d MMMM', 'ru').format(_selectedDay),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    Consumer<PlannerProvider>(
                      builder: (context, provider, child) {
                        final tasks = provider.getTasksForDate(_selectedDay);
                        final completed =
                            tasks.where((t) => t.completed).length;
                        return Text(
                          '$completed/${tasks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtextColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 20),
                      color: const Color(0xFF6366F1),
                      onPressed: () =>
                          _showAddTaskDialog(context, cardColor, textColor),
                      tooltip: 'Добавить задачу',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Task List
          Expanded(
            child: Consumer<PlannerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.alertCircle,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: TextStyle(color: subtextColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final tasks = provider.getTasksForDate(_selectedDay);
                final allTasks = provider.schedule?.tasks ?? [];

                if (tasks.isEmpty) {
                  // Show message with info about other days' tasks
                  if (allTasks.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.calendar,
                              color: subtextColor, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Нет задач на этот день',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'У вас есть ${allTasks.length} задач на эту неделю',
                            style: TextStyle(color: subtextColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите другой день в календаре',
                            style: TextStyle(color: subtextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.calendarCheck,
                            color: subtextColor, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Нет задач',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Сгенерируйте план с помощью AI',
                          style: TextStyle(color: subtextColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Dismissible(
                      key: Key(task.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Удалить задачу?'),
                                content: Text(
                                    'Вы уверены что хотите удалить "${task.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Удалить',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (direction) async {
                        final profileNotifier = Provider.of<ProfileNotifier>(
                            context,
                            listen: false);
                        final user = profileNotifier.user;
                        if (user != null) {
                          await provider.deleteTask(task.id, user.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Задача "${task.title}" удалена'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(LucideIcons.trash2,
                            color: Colors.red, size: 28),
                      ),
                      child: _buildTaskCard(
                        task,
                        cardColor,
                        textColor,
                        subtextColor,
                        provider,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    PlannerTask task,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
    PlannerProvider provider,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.completed
              ? const Color(0xFF10B981) // Зеленый для выполненных
              : priorityColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_togglingTaskId == task.id)
                return; // Предотвращаем двойное нажатие

              setState(() {
                _togglingTaskId = task.id;
              });

              final profileNotifier =
                  Provider.of<ProfileNotifier>(context, listen: false);
              final user = profileNotifier.user;
              if (user != null) {
                await provider.toggleTask(task.id, user.id);
                // Принудительно обновляем provider
                await provider.loadSchedule(user.id, forceRefresh: true);
              }

              if (mounted) {
                setState(() {
                  _togglingTaskId = null;
                });
              }
            },
            child: Container(
              width: 24,
              height: 24,
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : task.completed
                      ? const Icon(LucideIcons.check,
                          size: 16, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(task.completed ? 0.05 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: task.completed ? iconColor.withOpacity(0.4) : iconColor,
              size: 20,
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
                    fontWeight: FontWeight.w600,
                    color:
                        task.completed ? textColor.withOpacity(0.5) : textColor,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                    decorationColor:
                        task.completed ? textColor.withOpacity(0.5) : null,
                    decorationThickness: 2.0,
                  ),
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
            Icon(LucideIcons.flag, color: Colors.red, size: 16),
        ],
      ),
    );
  }

  void _generatePlan(BuildContext context) async {
    final profileNotifier =
        Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user == null) return;

    final provider = Provider.of<PlannerProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Генерация плана...'),
          ],
        ),
      ),
    );

    final success =
        await provider.generatePlan(user.id, targetDate: _selectedDay);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'План на ${DateFormat('d MMMM', 'ru').format(_selectedDay)} сгенерирован!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Ошибка генерации плана')),
        );
      }
    }
  }

  void _showAddTaskDialog(
      BuildContext context, Color cardColor, Color textColor) {
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новая задача',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  enabled: !_isAddingTask,
                  decoration: const InputDecoration(
                    hintText: 'Название задачи',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Text(
                  'На ${DateFormat('d MMMM', 'ru').format(_selectedDay)}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                if (_isAddingTask) ...[
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Создание задачи...'),
                    ],
                  ),
                ],
                if (!_isAddingTask) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          setState(() {
                            _isAddingTask = true;
                          });
                          setDialogState(() {});

                          final profileNotifier = Provider.of<ProfileNotifier>(
                              context,
                              listen: false);
                          final plannerProvider = Provider.of<PlannerProvider>(
                              context,
                              listen: false);
                          final user = profileNotifier.user;

                          if (user != null) {
                            final success = await plannerProvider.addCustomTask(
                              userId: user.id,
                              date: _selectedDay,
                              title: title,
                            );

                            if (mounted) {
                              setState(() {
                                _isAddingTask = false;
                              });

                              Navigator.pop(context);

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Задача добавлена ✓'),
                                    backgroundColor: Color(0xFF10B981),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ошибка добавления задачи'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            setState(() {
                              _isAddingTask = false;
                            });
                            setDialogState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Добавить'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
