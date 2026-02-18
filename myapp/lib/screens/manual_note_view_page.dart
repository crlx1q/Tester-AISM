import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/profile_notifier.dart';
import '../services/api_service.dart';
import '../models/notebook_entry.dart';
import 'manual_note_editor_page_new.dart';
import '../utils/icon_utils.dart';

class ManualNoteViewPage extends StatefulWidget {
  final NotebookEntry entry;

  const ManualNoteViewPage({
    Key? key,
    required this.entry,
  }) : super(key: key);

  @override
  State<ManualNoteViewPage> createState() => _ManualNoteViewPageState();
}

class _ManualNoteViewPageState extends State<ManualNoteViewPage> {
  late NotebookEntry _entry;
  final ApiService _api = ApiService();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _toggleChecklistItem(int index) async {
    final user = Provider.of<ProfileNotifier>(context, listen: false).user;
    if (user == null) return;

    setState(() {
      final updatedItems = List<ChecklistItem>.from(_entry.checklistItems);
      updatedItems[index] = updatedItems[index].copyWith(
        isCompleted: !updatedItems[index].isCompleted,
      );
      _entry = _entry.copyWith(checklistItems: updatedItems);
    });

    // Сохраняем на сервер
    try {
      await _api.updateNotebookEntry(
        userId: user.id,
        entryId: _entry.id,
        title: _entry.title,
        summary: _entry.summary,
        tags: _entry.tags,
        course: _entry.course,
        manualNotes: _entry.manualNotes,
        checklistItems: _entry.checklistItems.map((item) => item.toJson()).toList(),
        color: _entry.color,
        icon: _entry.icon,
        priority: _entry.priority.name,
        reminderDate: _entry.reminderDate,
        isPinned: _entry.isPinned,
      );
    } catch (e) {
      print('[NOTE_VIEW] Failed to update checklist: $e');
    }
  }

  Future<void> _openEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualNoteEditorPageNew(existingEntry: _entry),
      ),
    );

    if (result == true && mounted) {
      // Перезагрузить заметку
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final completedTasks = _entry.checklistItems.where((item) => item.isCompleted).length;
    final totalTasks = _entry.checklistItems.length;
    final selectedColor = _entry.color != null ? Color(_entry.color!) : const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Заметка'),
        actions: [
          if (_entry.isPinned)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(LucideIcons.pin, size: 20),
            ),
          IconButton(
            icon: const Icon(LucideIcons.edit),
            onPressed: _openEditor,
            tooltip: 'Редактировать',
          ),
        ],
      ),
      body: SafeArea(
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
                      color: selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      resolveLucideIcon(_entry.icon),
                      color: selectedColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _entry.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (_entry.summary.isNotEmpty)
                          Text(
                            _entry.summary,
                            style: TextStyle(color: subtextColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Приоритет и напоминание
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      _entry.priority == NotePriority.high
                          ? LucideIcons.alertCircle
                          : _entry.priority == NotePriority.normal
                              ? LucideIcons.circle
                              : LucideIcons.minus,
                      size: 16,
                    ),
                    label: Text(_entry.priority.displayName),
                    backgroundColor: selectedColor.withOpacity(0.2),
                  ),
                  if (_entry.reminderDate != null)
                    Chip(
                      avatar: const Icon(LucideIcons.bell, size: 16),
                      label: Text(DateFormat('dd MMM, HH:mm', 'ru').format(_entry.reminderDate!)),
                      backgroundColor: Colors.amber.withOpacity(0.2),
                    ),
                  if (_entry.isPinned)
                    const Chip(
                      avatar: Icon(LucideIcons.pin, size: 16),
                      label: Text('Закреплено'),
                      backgroundColor: Colors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Чеклист
              if (_entry.checklistItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Чеклист',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '$completedTasks/$totalTasks',
                            style: TextStyle(
                              color: subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (totalTasks > 0) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: completedTasks / totalTasks,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(selectedColor),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ..._entry.checklistItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _toggleChecklistItem(index),
                            child: Row(
                              children: [
                                Icon(
                                  item.isCompleted
                                      ? LucideIcons.checkCircle2
                                      : LucideIcons.circle,
                                  color: item.isCompleted ? Colors.green : Colors.grey,
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
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Markdown содержание
              if (_entry.manualNotes.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: _entry.manualNotes,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: textColor, fontSize: 14),
                      h1: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        color: selectedColor,
                        backgroundColor: Colors.grey[200],
                      ),
                      blockquote: TextStyle(
                        color: subtextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Курс и теги
              if (_entry.course.isNotEmpty || _entry.tags.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
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
                      if (_entry.course.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              LucideIcons.bookOpen,
                              size: 16,
                              color: selectedColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _entry.course,
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        ),
                        if (_entry.tags.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (_entry.tags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _entry.tags.map((tag) {
                            return Chip(
                              avatar: const Icon(LucideIcons.tag, size: 14),
                              label: Text(tag, style: const TextStyle(fontSize: 12)),
                              backgroundColor: selectedColor.withOpacity(0.2),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

