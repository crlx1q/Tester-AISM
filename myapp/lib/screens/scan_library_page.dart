import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ScanLibraryPage extends StatelessWidget {
  const ScanLibraryPage({super.key, required this.scans});

  final List<Map<String, dynamic>> scans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохранённые конспекты'),
      ),
      body: scans.isEmpty
          ? _buildEmptyState(theme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final scan = scans[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.fileText, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scan['title'] ?? 'Конспект',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  scan['summary'] ?? 'Сводка отсутствует',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMetaChip(
                            icon: LucideIcons.calendarDays,
                            text: _formatDate(scan['createdAt']),
                          ),
                          if (scan['subject'] != null)
                            _buildMetaChip(
                              icon: LucideIcons.graduationCap,
                              text: scan['subject'],
                            ),
                          if (scan['tags'] is List && (scan['tags'] as List).isNotEmpty)
                            ...((scan['tags'] as List).take(3).map(
                              (tag) => _buildMetaChip(
                                icon: LucideIcons.tag,
                                text: '#$tag',
                              ),
                            )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _ScanDetailsBottomSheet(scan: scan),
                              );
                            },
                            icon: const Icon(LucideIcons.eye),
                            label: const Text('Просмотр'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: scans.length,
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.fileText, size: 72, color: theme.disabledColor),
            const SizedBox(height: 16),
            const Text(
              'Сохранённых конспектов пока нет',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Отсканируйте конспект или добавьте его вручную, чтобы увидеть здесь AI-сводку и ключевые идеи.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String text}) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white.withOpacity(0.04),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Дата неизвестна';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return 'Дата неизвестна';
    }
  }
}

class _ScanDetailsBottomSheet extends StatelessWidget {
  const _ScanDetailsBottomSheet({required this.scan});

  final Map<String, dynamic> scan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan['title'] ?? 'Конспект',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(LucideIcons.calendar, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(scan['createdAt']),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (scan['summary'] != null && scan['summary'].toString().isNotEmpty) ...[
                        Text('Сводка', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(scan['summary'], style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                        const SizedBox(height: 20),
                      ],
                      if (scan['keyPoints'] is List && (scan['keyPoints'] as List).isNotEmpty) ...[
                        Text('Ключевые мысли', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...((scan['keyPoints'] as List).map((point) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  '),
                                  Expanded(
                                    child: Text(point.toString(), style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                                  ),
                                ],
                              ),
                            ))),
                        const SizedBox(height: 20),
                      ],
                      if (scan['questions'] is List && (scan['questions'] as List).isNotEmpty) ...[
                        Text('Контрольные вопросы', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...((scan['questions'] as List).map((question) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  '),
                                  Expanded(
                                    child: Text(question.toString(), style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                                  ),
                                ],
                              ),
                            ))),
                        const SizedBox(height: 20),
                      ],
                      if (scan['flashcards'] is List && (scan['flashcards'] as List).isNotEmpty) ...[
                        Text('Карточки для обучения', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...((scan['flashcards'] as List).map((card) {
                              final term = card['term'] ?? card['question'] ?? 'Термин';
                              final definition = card['definition'] ?? card['answer'] ?? 'Описание отсутствует';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(term.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(definition.toString(), style: theme.textTheme.bodyMedium),
                                  ],
                                ),
                              );
                            })),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Дата неизвестна';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return 'Дата неизвестна';
    }
  }
}
