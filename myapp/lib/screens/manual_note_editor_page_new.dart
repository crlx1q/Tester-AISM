import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/profile_notifier.dart';
import '../services/api_service.dart';
import '../models/notebook_entry.dart';
import '../utils/icon_utils.dart';

class ManualNoteEditorPageNew extends StatefulWidget {
  final NotebookEntry? existingEntry;

  const ManualNoteEditorPageNew({
    Key? key,
    this.existingEntry,
  }) : super(key: key);

  @override
  State<ManualNoteEditorPageNew> createState() =>
      _ManualNoteEditorPageNewState();
}

class _ManualNoteEditorPageNewState extends State<ManualNoteEditorPageNew>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  final _courseController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final List<ChecklistItem> _checklistItems = [];
  final TextEditingController _checklistController = TextEditingController();

  final ApiService _api = ApiService();
  bool _isSaving = false;
  bool _showPreview = false;
  late TabController _tabController;

  // Расширенные поля
  int _selectedColorValue = Colors.indigo.value;
  int _selectedIconCodePoint = LucideIcons.fileText.codePoint!;
  NotePriority _priority = NotePriority.normal;
  DateTime? _reminderDate;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.title;
      _summaryController.text = widget.existingEntry!.summary;
      _notesController.text = widget.existingEntry!.manualNotes;
      _courseController.text = widget.existingEntry!.course;
      _tags.addAll(widget.existingEntry!.tags);
      _checklistItems.addAll(widget.existingEntry!.checklistItems);
      _selectedColorValue = widget.existingEntry!.color ?? Colors.indigo.value;
      _selectedIconCodePoint =
          widget.existingEntry!.icon ?? LucideIcons.fileText.codePoint!;
      _priority = widget.existingEntry!.priority;
      _reminderDate = widget.existingEntry!.reminderDate;
      _isPinned = widget.existingEntry!.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    _courseController.dispose();
    _tagController.dispose();
    _checklistController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название заметки')),
      );
      return;
    }

    final user = Provider.of<ProfileNotifier>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final noteData = {
        'title': _titleController.text.trim(),
        'summary': _summaryController.text.trim(),
        'manualNotes': _notesController.text.trim(),
        'course': _courseController.text.trim(),
        'tags': _tags,
        'color': _selectedColorValue,
        'icon': _selectedIconCodePoint,
        'priority': _priority.name,
        if (_reminderDate != null)
          'reminderDate': _reminderDate!.toIso8601String(),
        'checklistItems': _checklistItems.map((item) => item.toJson()).toList(),
        'isPinned': _isPinned,
      };

      if (widget.existingEntry != null) {
        await _api.updateNotebookEntry(
          userId: user.id,
          entryId: widget.existingEntry!.id,
          title: noteData['title'] as String,
          summary: noteData['summary'] as String,
          tags: noteData['tags'] as List<String>,
          course: noteData['course'] as String,
          manualNotes: noteData['manualNotes'] as String,
          color: noteData['color'] as int,
          icon: noteData['icon'] as int,
          priority: noteData['priority'] as String,
          reminderDate: noteData['reminderDate'] != null
              ? DateTime.parse(noteData['reminderDate'] as String)
              : null,
          checklistItems: noteData['checklistItems'] as List,
          isPinned: noteData['isPinned'] as bool,
        );
      } else {
        await _api.createNotebookEntry(
          userId: user.id,
          type: 'manual',
          title: noteData['title'] as String,
          summary: noteData['summary'] as String,
          tags: noteData['tags'] as List<String>,
          course: noteData['course'] as String,
          manualNotes: noteData['manualNotes'] as String,
          color: noteData['color'] as int,
          icon: noteData['icon'] as int,
          priority: noteData['priority'] as String,
          reminderDate: noteData['reminderDate'] != null
              ? DateTime.parse(noteData['reminderDate'] as String)
              : null,
          checklistItems: noteData['checklistItems'] as List,
          isPinned: noteData['isPinned'] as bool,
        );

        // Report notebook creation activity to update streak
        try {
          await _api.reportActivity(
            userId: user.id,
            type: 'notebook',
            minutes: 5, // Средняя продолжительность создания конспекта
          );
          print('[STATS] Reported notebook creation activity');
        } catch (e) {
          print('[STATS] Failed to report notebook activity: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(widget.existingEntry != null
                    ? 'Заметка обновлена!'
                    : 'Заметка создана!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _addChecklistItem() {
    final text = _checklistController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _checklistItems.add(ChecklistItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
        ));
        _checklistController.clear();
      });
    }
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      _checklistItems[index] = _checklistItems[index].copyWith(
        isCompleted: !_checklistItems[index].isCompleted,
      );
    });
  }

  void _removeChecklistItem(int index) {
    setState(() => _checklistItems.removeAt(index));
  }

  void _showIconPicker() {
    final icons = [
      LucideIcons.fileText,
      LucideIcons.book,
      LucideIcons.brain,
      LucideIcons.lightbulb,
      LucideIcons.star,
      LucideIcons.heart,
      LucideIcons.zap,
      LucideIcons.target,
      LucideIcons.award,
      LucideIcons.briefcase,
      LucideIcons.coffee,
      LucideIcons.code,
      LucideIcons.compass,
      LucideIcons.flame,
      LucideIcons.globe,
      LucideIcons.music,
      LucideIcons.palette,
      LucideIcons.shield,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите иконку'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            children: icons.map((icon) {
              final isSelected = icon.codePoint == _selectedIconCodePoint;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIconCodePoint = icon.codePoint!);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(_selectedColorValue).withOpacity(0.2)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Color(_selectedColorValue)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Color(_selectedColorValue)
                        : Colors.grey[600],
                    size: 28,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      Colors.indigo,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите цвет'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final isSelected = color.value == _selectedColorValue;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColorValue = color.value);
                Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(LucideIcons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickReminderDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _reminderDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
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
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.existingEntry != null
            ? 'Редактировать заметку'
            : 'Новая заметка'),
        actions: [
          IconButton(
            icon: Icon(_isPinned ? LucideIcons.pin : LucideIcons.pinOff),
            onPressed: () => setState(() => _isPinned = !_isPinned),
            tooltip: _isPinned ? 'Открепить' : 'Закрепить',
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.save),
              onPressed: _saveNote,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.edit), text: 'Редактор'),
            Tab(icon: Icon(LucideIcons.eye), text: 'Превью'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditorTab(cardColor, textColor, subtextColor),
          _buildPreviewTab(cardColor, textColor, subtextColor),
        ],
      ),
    );
  }

  Widget _buildEditorTab(
      Color cardColor, Color textColor, Color? subtextColor) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Иконка и цвет
            Row(
              children: [
                GestureDetector(
                  onTap: _showIconPicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(_selectedColorValue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Color(_selectedColorValue), width: 2),
                    ),
                    child: Icon(
                      resolveLucideIcon(_selectedIconCodePoint),
                      color: Color(_selectedColorValue),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showColorPicker,
                  icon: const Icon(LucideIcons.palette, size: 18),
                  label: const Text('Цвет'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue),
                    foregroundColor: Colors.white,
                  ),
                ),
                const Spacer(),
                DropdownButton<NotePriority>(
                  value: _priority,
                  items: NotePriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            priority == NotePriority.high
                                ? LucideIcons.alertCircle
                                : priority == NotePriority.normal
                                    ? LucideIcons.circle
                                    : LucideIcons.minus,
                            size: 16,
                            color: priority == NotePriority.high
                                ? Colors.red
                                : priority == NotePriority.normal
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(priority.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Название
            TextField(
              controller: _titleController,
              style: TextStyle(
                  color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Название заметки',
                hintStyle: TextStyle(color: subtextColor),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),

            // Краткое описание
            TextField(
              controller: _summaryController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Краткое описание',
                hintStyle: TextStyle(color: subtextColor),
                border: InputBorder.none,
              ),
              maxLines: 2,
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Чеклист
            if (_checklistItems.isNotEmpty) ...[
              Text('Чеклист',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 8),
              ..._checklistItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeChecklistItem(index),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Colors.red,
                    child: const Icon(LucideIcons.trash2, color: Colors.white),
                  ),
                  child: CheckboxListTile(
                    value: item.isCompleted,
                    onChanged: (_) => _toggleChecklistItem(index),
                    title: Text(
                      item.text,
                      style: TextStyle(
                        color: textColor,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],

            // Добавить пункт чеклиста
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checklistController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Добавить пункт',
                      hintStyle: TextStyle(color: subtextColor),
                      prefixIcon: const Icon(LucideIcons.checkSquare, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _addChecklistItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addChecklistItem,
                  icon: const Icon(LucideIcons.plus),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Содержание (Markdown)
            Text('Содержание',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Введите текст заметки (поддерживает Markdown)',
                hintStyle: TextStyle(color: subtextColor),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                helperText: '**жирный**, *курсив*, - список, [ ] чекбокс',
                helperStyle: TextStyle(color: subtextColor, fontSize: 11),
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16),

            // Курс
            TextField(
              controller: _courseController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Курс',
                prefixIcon: const Icon(LucideIcons.bookOpen, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Теги
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Добавить тег',
                      prefixIcon: const Icon(LucideIcons.tag, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(LucideIcons.plus),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: TextStyle(color: textColor)),
                    backgroundColor:
                        Color(_selectedColorValue).withOpacity(0.2),
                    deleteIcon: const Icon(LucideIcons.x, size: 18),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Напоминание
            ListTile(
              leading:
                  Icon(LucideIcons.bell, color: Color(_selectedColorValue)),
              title: Text(
                _reminderDate != null
                    ? 'Напомнить: ${DateFormat('dd MMM yyyy, HH:mm', 'ru').format(_reminderDate!)}'
                    : 'Добавить напоминание',
                style: TextStyle(color: textColor),
              ),
              trailing: _reminderDate != null
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => setState(() => _reminderDate = null),
                    )
                  : null,
              onTap: _pickReminderDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: subtextColor!),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab(
      Color cardColor, Color textColor, Color? subtextColor) {
    final completedTasks =
        _checklistItems.where((item) => item.isCompleted).length;
    final totalTasks = _checklistItems.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header с иконкой
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(_selectedColorValue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    resolveLucideIcon(_selectedIconCodePoint),
                    color: Color(_selectedColorValue),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isNotEmpty
                            ? _titleController.text
                            : 'Без названия',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor),
                      ),
                      if (_summaryController.text.isNotEmpty)
                        Text(
                          _summaryController.text,
                          style: TextStyle(color: subtextColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Приоритет и напоминание
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    _priority == NotePriority.high
                        ? LucideIcons.alertCircle
                        : _priority == NotePriority.normal
                            ? LucideIcons.circle
                            : LucideIcons.minus,
                    size: 16,
                  ),
                  label: Text(_priority.displayName),
                  backgroundColor: Color(_selectedColorValue).withOpacity(0.2),
                ),
                if (_reminderDate != null)
                  Chip(
                    avatar: const Icon(LucideIcons.bell, size: 16),
                    label: Text(
                        DateFormat('dd MMM, HH:mm', 'ru').format(_reminderDate!)),
                    backgroundColor: Colors.amber.withOpacity(0.2),
                  ),
                if (_isPinned)
                  const Chip(
                    avatar: Icon(LucideIcons.pin, size: 16),
                    label: Text('Закреплено'),
                    backgroundColor: Colors.blue,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Чеклист
            if (_checklistItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Чеклист',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        Text(
                          '$completedTasks/$totalTasks',
                          style: TextStyle(color: subtextColor),
                        ),
                      ],
                    ),
                    if (totalTasks > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completedTasks / totalTasks,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(_selectedColorValue)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ..._checklistItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              item.isCompleted
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.circle,
                              color:
                                  item.isCompleted ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.text,
                                style: TextStyle(
                                  color: textColor,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Markdown содержание
            if (_notesController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MarkdownBody(
                  data: _notesController.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor, fontSize: 14),
                    h1: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    h2: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    h3: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    code: TextStyle(
                        color: Color(_selectedColorValue),
                        backgroundColor: Colors.grey[200]),
                    blockquote: TextStyle(
                        color: subtextColor, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Курс и теги
            if (_courseController.text.isNotEmpty || _tags.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_courseController.text.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(LucideIcons.bookOpen,
                              size: 16, color: Color(_selectedColorValue)),
                          const SizedBox(width: 8),
                          Text(_courseController.text,
                              style: TextStyle(color: textColor)),
                        ],
                      ),
                      if (_tags.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            avatar: const Icon(LucideIcons.tag, size: 14),
                            label:
                                Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                Color(_selectedColorValue).withOpacity(0.2),
                          );
                        }).toList(),
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
}
