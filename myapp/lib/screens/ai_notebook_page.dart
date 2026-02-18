import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notebook_entry.dart';
import '../providers/notebook_provider.dart';
import '../services/profile_notifier.dart';
import '../services/api_service.dart';
import '../models/ai_lecture.dart';
import '../models/ai_scan_note.dart';
import '../models/ai_session.dart';
import 'lecture_detail_page.dart';
import 'scan_note_detail_page.dart';
import 'session_detail_page.dart';
import 'manual_note_editor_page_new.dart';
import 'manual_note_view_page.dart';

class AiNotebookPage extends StatefulWidget {
  const AiNotebookPage({Key? key}) : super(key: key);

  @override
  State<AiNotebookPage> createState() => _AiNotebookPageState();
}

class _AiNotebookPageState extends State<AiNotebookPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService();
  EntryType? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
    });
  }

  void _loadEntries() {
    final profileNotifier =
        Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user != null) {
      print(
          '[NOTEBOOK] Loading entries with filter type: ${_selectedType?.name}');
      Provider.of<NotebookProvider>(context, listen: false).loadEntries(
        user.id,
        type: _selectedType?.name,
        search:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        forceRefresh: true, // Force refresh when filter changes
      );
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
          'AI Notebook',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: textColor),
            onPressed: () => _showAddNoteDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Поиск по заметкам...',
                hintStyle: TextStyle(color: subtextColor),
                prefixIcon: Icon(LucideIcons.search, color: subtextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(LucideIcons.x, color: subtextColor),
                        onPressed: () {
                          _searchController.clear();
                          _loadEntries();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _loadEntries();
                  }
                });
              },
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Все', _selectedType == null, () {
                  setState(() {
                    _selectedType = null;
                  });
                  _loadEntries();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Лекции', _selectedType == EntryType.lecture,
                    () {
                  setState(() {
                    _selectedType = EntryType.lecture;
                  });
                  _loadEntries();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Конспекты', _selectedType == EntryType.scan,
                    () {
                  setState(() {
                    _selectedType = EntryType.scan;
                  });
                  _loadEntries();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Сессии', _selectedType == EntryType.session,
                    () {
                  setState(() {
                    _selectedType = EntryType.session;
                  });
                  _loadEntries();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Заметки', _selectedType == EntryType.manual,
                    () {
                  setState(() {
                    _selectedType = EntryType.manual;
                  });
                  _loadEntries();
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Entries List
          Expanded(
            child: Consumer<NotebookProvider>(
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEntries,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.book, color: subtextColor, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Пока нет записей',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте свою первую заметку',
                          style: TextStyle(color: subtextColor),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadEntries(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.entries.length,
                    itemBuilder: (context, index) {
                      final entry = provider.entries[index];
                      return _buildEntryCard(
                          entry, cardColor, textColor, subtextColor);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    NotebookEntry entry,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    IconData icon;
    Color iconColor;

    switch (entry.type) {
      case EntryType.lecture:
        icon = LucideIcons.mic;
        iconColor = Colors.blue;
        break;
      case EntryType.scan:
        icon = LucideIcons.scan;
        iconColor = Colors.green;
        break;
      case EntryType.session:
        icon = LucideIcons.messageSquare;
        iconColor = Colors.purple;
        break;
      case EntryType.manual:
        icon = LucideIcons.edit;
        iconColor = Colors.orange;
        break;
    }

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить запись?'),
            content: Text('Вы уверены, что хотите удалить "${entry.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final user = Provider.of<ProfileNotifier>(context, listen: false).user;
        if (user != null) {
          try {
            await _api.deleteNotebookEntry(user.id, entry.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Запись удалена'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            _loadEntries();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка удаления: $e')),
              );
            }
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () => _openEntry(entry),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd MMM yyyy', 'ru').format(entry.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  entry.summary,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEntry(NotebookEntry entry) async {
    final user = Provider.of<ProfileNotifier>(context, listen: false).user;
    if (user == null) return;

    print('[NOTEBOOK] Opening entry: ${entry.id}, type: ${entry.type}');

    try {
      final result = await _api.getNotebookEntry(user.id, entry.id);
      print('[NOTEBOOK] getNotebookEntry result: $result');

      if (result['success'] == true && result['data'] != null) {
        // Server returns double-nested structure: {success: true, data: {success: true, data: {...}}}
        final outerData = result['data'];
        final data = outerData['data'] ?? outerData; // Handle both cases
        final linkedResource = data['linkedResource'];
        print('[NOTEBOOK] linkedResource: $linkedResource');

        if (!mounted) return;

        switch (entry.type) {
          case EntryType.lecture:
            if (linkedResource != null) {
              print('[NOTEBOOK] Opening lecture detail');
              final lecture = AiLecture.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LectureDetailPage(lecture: lecture),
                ),
              );
            } else {
              print('[NOTEBOOK] linkedResource is null for lecture');
              print('[NOTEBOOK] Full data: $data');
              print(
                  '[NOTEBOOK] Entry linkedResourceId: ${entry.linkedResourceId}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Лекция не найдена (ID: ${entry.linkedResourceId ?? "отсутствует"})')),
                );
              }
            }
            break;
          case EntryType.scan:
            if (linkedResource != null) {
              print('[NOTEBOOK] Opening scan detail');
              final scan = AiScanNote.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanNoteDetailPage(scanNote: scan),
                ),
              );
            } else {
              print('[NOTEBOOK] linkedResource is null for scan');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Конспект не найден')),
                );
              }
            }
            break;
          case EntryType.session:
            if (linkedResource != null) {
              print('[NOTEBOOK] Opening session detail');
              final session = AiSession.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailPage(session: session),
                ),
              );
            } else {
              print('[NOTEBOOK] linkedResource is null for session');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сессия не найдена')),
                );
              }
            }
            break;
          case EntryType.manual:
            print('[NOTEBOOK] Opening manual note in view mode');
            // For manual notes, open view page (not editor)
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManualNoteViewPage(
                  entry: entry,
                ),
              ),
            );
            if (result == true && mounted) {
              _loadEntries(); // Reload entries after changes
            }
            break;
        }
      } else {
        print('[NOTEBOOK] Result is not successful or data is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запись не найдена')),
          );
        }
      }
    } catch (e) {
      print('[NOTEBOOK] Error opening entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _showAddNoteDialog(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualNoteEditorPageNew(),
      ),
    );

    if (result == true) {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
