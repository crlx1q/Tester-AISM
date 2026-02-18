import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/ai_lecture.dart';

class LectureDetailPage extends StatefulWidget {
  final AiLecture lecture;

  const LectureDetailPage({Key? key, required this.lecture}) : super(key: key);

  @override
  State<LectureDetailPage> createState() => _LectureDetailPageState();
}

class _LectureDetailPageState extends State<LectureDetailPage>
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
          widget.lecture.title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.share2, color: textColor),
            onPressed: () => _shareLeture(),
          ),
          IconButton(
            icon: Icon(LucideIcons.moreVertical, color: textColor),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header card
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.mic, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Умная лекция',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDuration(widget.lecture.durationSeconds)} · ${widget.lecture.keyConcepts.length} понятий',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: subtextColor,
              indicatorColor: const Color(0xFF6366F1),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Транскрипт'),
                Tab(text: 'Сводка'),
                Tab(text: 'Понятия'),
                Tab(text: 'Вопросы'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTranscriptTab(cardColor, textColor, subtextColor),
                _buildSummaryTab(cardColor, textColor, subtextColor),
                _buildConceptsTab(cardColor, textColor, subtextColor),
                _buildQuestionsTab(cardColor, textColor, subtextColor),
              ],
            ),
          ),
        ],
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
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openInChat(context),
              icon: const Icon(LucideIcons.messageSquare),
              label: const Text('В чат'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptTab(Color cardColor, Color textColor, Color? subtextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          widget.lecture.transcription,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab(Color cardColor, Color textColor, Color? subtextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.fileText, color: Color(0xFF6366F1), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Краткое содержание',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.lecture.summary,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConceptsTab(Color cardColor, Color textColor, Color? subtextColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.lecture.keyConcepts.length,
      itemBuilder: (context, index) {
        final concept = widget.lecture.keyConcepts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  concept,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestionsTab(Color cardColor, Color textColor, Color? subtextColor) {
    if (widget.lecture.questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.helpCircle, color: subtextColor, size: 64),
            const SizedBox(height: 16),
            Text(
              'Нет вопросов',
              style: TextStyle(color: subtextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.lecture.questions.length,
      itemBuilder: (context, index) {
        final question = widget.lecture.questions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.purple.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.helpCircle, color: Colors.purple, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _shareLeture() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция поделиться в разработке')),
    );
  }

  void _showOptions(BuildContext context) {
    // TODO: Implement options menu
  }

  void _createCards(BuildContext context) {
    // TODO: Navigate to create set page with lecture context
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Создание карточек из лекции...')),
    );
  }

  void _openInChat(BuildContext context) {
    // TODO: Open tutor page with lecture context
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Открытие в чате...')),
    );
  }
}

