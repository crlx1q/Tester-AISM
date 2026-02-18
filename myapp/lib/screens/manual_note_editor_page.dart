import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/profile_notifier.dart';
import '../services/api_service.dart';
import '../models/notebook_entry.dart';

class ManualNoteEditorPage extends StatefulWidget {
  final NotebookEntry? existingEntry;
  final Map<String, dynamic>? existingData;

  const ManualNoteEditorPage({
    Key? key,
    this.existingEntry,
    this.existingData,
  }) : super(key: key);

  @override
  State<ManualNoteEditorPage> createState() => _ManualNoteEditorPageState();
}

class _ManualNoteEditorPageState extends State<ManualNoteEditorPage> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  final _courseController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final ApiService _api = ApiService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null && widget.existingData != null) {
      _titleController.text = widget.existingEntry!.title;
      _summaryController.text = widget.existingEntry!.summary;
      _courseController.text = widget.existingEntry!.course ?? '';
      _tags.addAll(widget.existingEntry!.tags);

      final manualNotes = widget.existingData!['manualNotes'];
      if (manualNotes != null) {
        _notesController.text = manualNotes.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    _courseController.dispose();
    _tagController.dispose();
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
      if (widget.existingEntry != null) {
        // Update existing entry
        await _api.updateNotebookEntry(
          userId: user.id,
          entryId: widget.existingEntry!.id,
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          tags: _tags,
          course: _courseController.text.trim(),
          manualNotes: _notesController.text.trim(),
        );
      } else {
        // Create new entry
        await _api.createNotebookEntry(
          userId: user.id,
          type: 'manual',
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          tags: _tags,
          course: _courseController.text.trim(),
          manualNotes: _notesController.text.trim(),
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
              content: Text(widget.existingEntry != null
                  ? 'Заметка обновлена!'
                  : 'Заметка сохранена!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
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
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.check),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                hintText: 'Название заметки',
                hintStyle: TextStyle(color: subtextColor),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _summaryController,
                style: TextStyle(color: textColor),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Краткое описание...',
                  hintStyle: TextStyle(color: subtextColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _notesController,
                style: TextStyle(color: textColor),
                maxLines: 15,
                decoration: InputDecoration(
                  hintText: 'Ваши заметки...',
                  hintStyle: TextStyle(color: subtextColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Course
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.book, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _courseController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Курс или предмет',
                        hintStyle: TextStyle(color: subtextColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tags
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
                    children: [
                      const Icon(LucideIcons.tag, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Добавить тег',
                            hintStyle: TextStyle(color: subtextColor),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.plus, size: 20),
                        onPressed: _addTag,
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
                          label: Text(tag),
                          deleteIcon: const Icon(LucideIcons.x, size: 16),
                          onDeleted: () => _removeTag(tag),
                          backgroundColor:
                              const Color(0xFF6366F1).withOpacity(0.1),
                          labelStyle: const TextStyle(color: Color(0xFF6366F1)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
