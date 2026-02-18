import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/ai_scan_note.dart';
import '../widgets/image_viewer.dart';
import '../services/profile_notifier.dart';
import '../services/pdf_export_service.dart';
import '../widgets/premium_modal.dart';

class ScanNoteDetailPage extends StatefulWidget {
  final AiScanNote scanNote;

  const ScanNoteDetailPage({Key? key, required this.scanNote})
      : super(key: key);

  @override
  State<ScanNoteDetailPage> createState() => _ScanNoteDetailPageState();
}

class _ScanNoteDetailPageState extends State<ScanNoteDetailPage> {
  late TextEditingController _notesController;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.scanNote.manualNotes);
    // Отладка: проверяем наличие imageUrl
    print('[SCAN_DETAIL] imageUrl: ${widget.scanNote.imageUrl}');
    print(
        '[SCAN_DETAIL] imageUrl isEmpty: ${widget.scanNote.imageUrl?.isEmpty}');
    print('[SCAN_DETAIL] imageUrl isNull: ${widget.scanNote.imageUrl == null}');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          'Живой конспект',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<ProfileNotifier>(
            builder: (context, profileNotifier, child) {
              final user = profileNotifier.user;
              final isPro = user?.pro?.status == true;
              
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(LucideIcons.fileDown, color: textColor),
                    if (!isPro)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 12,
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _exportToPdf(isPro),
                tooltip: 'Экспорт в PDF',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото конспекта с возможностью зума
            if (widget.scanNote.imageUrl != null &&
                widget.scanNote.imageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок секции фото
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.image,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Фото конспекта',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Фото в рамке
                    GestureDetector(
                      onTap: () {
                        ImageViewer.show(
                          context,
                          widget.scanNote.imageUrl!,
                          title: widget.scanNote.title,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            height: 220, // Фиксированная высота формочки
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: Stack(
                              children: [
                                // Иконка заглушка на фоне
                                Center(
                                  child: Icon(
                                    LucideIcons.image,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                ),

                                // Само изображение с адаптацией
                                Center(
                                  child: _buildAdaptiveImage(
                                      widget.scanNote.imageUrl!),
                                ),

                                // Градиент снизу для лучшей читаемости текста
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Кнопка зума
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.expand,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Увеличить',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Header
            Container(
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.scan,
                        color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.scanNote.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (widget.scanNote.course.isNotEmpty)
                          Text(
                            widget.scanNote.course,
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
            ),

            const SizedBox(height: 20),

            // Summary
            _buildSection(
              'Краткое содержание',
              LucideIcons.fileText,
              Colors.blue,
              cardColor,
              textColor,
              child: Text(
                widget.scanNote.summary,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Concepts
            if (widget.scanNote.concepts.isNotEmpty)
              _buildSection(
                'Ключевые понятия',
                LucideIcons.lightbulb,
                Colors.purple,
                cardColor,
                textColor,
                child: Column(
                  children: widget.scanNote.concepts.map((concept) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.checkCircle2,
                            color: Colors.purple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              concept,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            // Formulas
            if (widget.scanNote.formulas.isNotEmpty)
              _buildSection(
                'Формулы',
                LucideIcons.calculator,
                Colors.orange,
                cardColor,
                textColor,
                child: Column(
                  children: widget.scanNote.formulas.map((formula) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        formula,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            // Manual Notes
            _buildSection(
              'Мои заметки',
              LucideIcons.edit,
              Colors.green,
              cardColor,
              textColor,
              child: Column(
                children: [
                  if (_isEditingNotes)
                    TextField(
                      controller: _notesController,
                      maxLines: 5,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Добавьте свои заметки...',
                        hintStyle: TextStyle(color: subtextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _isEditingNotes = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          widget.scanNote.manualNotes.isEmpty
                              ? 'Нажмите, чтобы добавить заметки...'
                              : widget.scanNote.manualNotes,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.scanNote.manualNotes.isEmpty
                                ? subtextColor
                                : textColor,
                          ),
                        ),
                      ),
                    ),
                  if (_isEditingNotes)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _notesController.text = widget.scanNote.manualNotes;
                            setState(() => _isEditingNotes = false);
                          },
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNotes,
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tags
            if (widget.scanNote.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.scanNote.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _createCards(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Создать карточки'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color,
      Color cardColor, Color textColor,
      {required Widget child}) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _saveNotes() {
    // TODO: Save notes to backend
    setState(() {
      _isEditingNotes = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заметки сохранены')),
    );
  }

  Future<void> _exportToPdf(bool isPro) async {
    if (!isPro) {
      // Показываем модальное окно Premium
      PremiumModal.show(context);
      return;
    }

    try {
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Создание PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Экспортируем в PDF
      await PdfExportService.exportScanNoteToPdf(widget.scanNote);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF успешно создан!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _createCards(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Создание карточек из конспекта...')),
    );
  }

  Widget _buildAdaptiveImage(String imageUrl) {
    // Проверяем формат изображения (base64 или URL)
    if (imageUrl.startsWith('data:image')) {
      // Base64 изображение
      final base64String = imageUrl.split(',').last;
      try {
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit
              .contain, // Адаптация под размер контейнера с сохранением пропорций
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    } else {
      // URL изображение
      return Image.network(
        imageUrl,
        fit: BoxFit
            .contain, // Адаптация под размер контейнера с сохранением пропорций
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Загрузка...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }
  }
}
