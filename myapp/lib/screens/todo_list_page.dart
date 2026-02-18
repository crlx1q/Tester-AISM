import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../models/todo_task.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_task_card.dart';
import '../widgets/add_todo_dialog.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок
            _buildHeader(context, todoProvider, isDark),
            
            // Статистика
            _buildStats(todoProvider, isDark),

            // Вкладки
            _buildTabs(isDark),

            // Список задач
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(todoProvider, null, isDark),
                  _buildTaskList(todoProvider, 'today', isDark),
                  _buildTaskList(todoProvider, 'week', isDark),
                  _buildTaskList(todoProvider, 'overdue', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'Новая задача',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TodoProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Мои задачи',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMMM, EEEE', 'ru_RU').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Меню
          PopupMenuButton<String>(
            icon: Icon(
              LucideIcons.moreVertical,
              color: isDark ? Colors.white : Colors.black,
            ),
            onSelected: (value) {
              if (value == 'toggle_completed') {
                provider.toggleShowCompleted();
              } else if (value == 'clear_completed') {
                _showClearCompletedDialog(context, provider);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_completed',
                child: Row(
                  children: [
                    Icon(
                      provider.showCompleted
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(provider.showCompleted
                        ? 'Скрыть завершённые'
                        : 'Показать завершённые'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Удалить завершённые',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(TodoProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Всего', provider.totalTasks.toString(), LucideIcons.listTodo),
                _buildStatItem('Активных', provider.activeTasks.toString(), LucideIcons.clock),
                _buildStatItem('Выполнено', provider.completedTasks.toString(), LucideIcons.checkCircle2),
              ],
            ),
            const SizedBox(height: 16),
            // Прогресс-бар
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Общий прогресс',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${provider.completionPercentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: provider.completionPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.zero,
        indicatorPadding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Все'),
          Tab(text: 'Сегодня'),
          Tab(text: 'Неделя'),
          Tab(text: 'Просрочено'),
        ],
      ),
    );
  }

  Widget _buildTaskList(TodoProvider provider, String? filter, bool isDark) {
    List<TodoTask> tasks;
    
    switch (filter) {
      case 'today':
        tasks = provider.getTodayTasks();
        break;
      case 'week':
        tasks = provider.getWeekTasks();
        break;
      case 'overdue':
        tasks = provider.getOverdueTasks();
        break;
      default:
        tasks = provider.filteredTasks;
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.checkCircle2,
              size: 64,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              filter == 'overdue'
                  ? 'Нет просроченных задач 🎉'
                  : 'Нет задач',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте новую задачу',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onReorder: (oldIndex, newIndex) {
        provider.reorderTasks(oldIndex, newIndex);
      },
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          key: ValueKey(task.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: TodoTaskCard(
            task: task,
            onTap: () => _showEditTaskDialog(context, task),
            onToggle: () => provider.toggleTaskCompletion(task.id),
            onDelete: () => _showDeleteConfirmation(context, provider, task),
            onProgressChanged: (progress) =>
                provider.updateTaskProgress(task.id, progress),
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddTodoDialog(),
    );
  }

  void _showEditTaskDialog(BuildContext context, TodoTask task) {
    showDialog(
      context: context,
      builder: (context) => AddTodoDialog(task: task),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, TodoProvider provider, TodoTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('Вы уверены, что хотите удалить "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteTask(task.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showClearCompletedDialog(
      BuildContext context, TodoProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить завершённые?'),
        content: Text(
            'Вы уверены, что хотите удалить все завершённые задачи (${provider.completedTasks})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              provider.clearCompletedTasks();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

