import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notebook_entry.dart';
import '../providers/notebook_provider.dart';
import '../screens/lecture_detail_page.dart';
import '../screens/scan_note_detail_page.dart';
import '../screens/session_detail_page.dart';
import '../screens/manual_note_view_page.dart';
import '../models/ai_lecture.dart';
import '../models/ai_scan_note.dart';
import '../models/ai_session.dart';
import '../services/api_service.dart';
import '../services/profile_notifier.dart';

class RecentMaterialsCarousel extends StatefulWidget {
  final Function(NotebookEntry)? onTap;

  const RecentMaterialsCarousel({Key? key, this.onTap}) : super(key: key);

  @override
  State<RecentMaterialsCarousel> createState() => _RecentMaterialsCarouselState();
}

class _RecentMaterialsCarouselState extends State<RecentMaterialsCarousel> {
  final ApiService _api = ApiService();
  String? _selectedEntryId;

  Future<void> _openEntry(NotebookEntry entry) async {
    // Показываем выделение рамки
    setState(() {
      _selectedEntryId = entry.id;
    });

    if (widget.onTap != null) {
      widget.onTap!(entry);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _selectedEntryId = null;
          });
        }
      });
      return;
    }

    final user = Provider.of<ProfileNotifier>(context, listen: false).user;
    if (user == null) {
      setState(() {
        _selectedEntryId = null;
      });
      return;
    }

    try {
      final result = await _api.getNotebookEntry(user.id, entry.id);
      
      if (result['success'] == true && result['data'] != null) {
        // Server returns double-nested structure: {success: true, data: {success: true, data: {...}}}
        final outerData = result['data'];
        final data = outerData['data'] ?? outerData; // Handle both cases
        final linkedResource = data['linkedResource'];
        
        if (!mounted) {
          setState(() {
            _selectedEntryId = null;
          });
          return;
        }
        
        // Убираем выделение после небольшой задержки
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _selectedEntryId = null;
            });
          }
        });
        
        switch (entry.type) {
          case EntryType.lecture:
            if (linkedResource != null) {
              final lecture = AiLecture.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LectureDetailPage(lecture: lecture),
                ),
              );
            }
            break;
          case EntryType.scan:
            if (linkedResource != null) {
              final scan = AiScanNote.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanNoteDetailPage(scanNote: scan),
                ),
              );
            }
            break;
          case EntryType.session:
            if (linkedResource != null) {
              final session = AiSession.fromJson(linkedResource);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailPage(session: session),
                ),
              );
            }
            break;
          case EntryType.manual:
            // Open manual note view page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManualNoteViewPage(entry: entry),
              ),
            );
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedEntryId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Недавние материалы',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<NotebookProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final recentEntries = provider.entries.take(5).toList();

            if (recentEntries.isEmpty) {
              return Container(
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.book, color: subtextColor, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Пока нет материалов',
                        style: TextStyle(color: subtextColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentEntries.length,
                itemBuilder: (context, index) {
                  final entry = recentEntries[index];
                  final isSelected = _selectedEntryId == entry.id;
                  return _buildMaterialCard(
                    entry,
                    isDark,
                    textColor,
                    subtextColor,
                    isSelected,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMaterialCard(
    NotebookEntry entry,
    bool isDark,
    Color textColor,
    Color? subtextColor,
    bool isSelected,
  ) {
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (entry.type) {
      case EntryType.lecture:
        icon = LucideIcons.mic;
        iconColor = Colors.blue;
        typeLabel = 'Лекция';
        break;
      case EntryType.scan:
        icon = LucideIcons.scan;
        iconColor = Colors.green;
        typeLabel = 'Конспект';
        break;
      case EntryType.session:
        icon = LucideIcons.messageSquare;
        iconColor = Colors.purple;
        typeLabel = 'Сессия';
        break;
      case EntryType.manual:
        icon = LucideIcons.edit;
        iconColor = Colors.orange;
        typeLabel = 'Заметка';
        break;
    }

    return GestureDetector(
      onTap: () => _openEntry(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? iconColor.withOpacity(0.8)
                : iconColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              DateFormat('dd MMM', 'ru').format(entry.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: subtextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

