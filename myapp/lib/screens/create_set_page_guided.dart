import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/study_set.dart';
import '../models/notebook_entry.dart';
import '../services/study_sets_service.dart';
import '../services/api_service.dart';
import '../services/profile_notifier.dart';
import '../services/achievements_service.dart';
import '../providers/notebook_provider.dart';

enum SetSource { aiLecture, aiScan, manual, empty }

class CreateSetPageGuided extends StatefulWidget {
  const CreateSetPageGuided({Key? key}) : super(key: key);

  @override
  State<CreateSetPageGuided> createState() => _CreateSetPageGuidedState();
}

class _CreateSetPageGuidedState extends State<CreateSetPageGuided> {
  int _currentStep = 0;
  SetSource? _selectedSource;
  NotebookEntry? _selectedEntry;
  List<StudyCard> _cards = [];
  final Set<int> _selectedCardIndices = {};
  
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  final _tagsController = TextEditingController();
  final AchievementsService _achievementsService = AchievementsService();
  
  IconData _selectedIcon = LucideIcons.layers;
  Color _selectedColor = Colors.indigo;
  
  bool _isGenerating = false;
  bool _isSaving = false;

  final ApiService _api = ApiService();

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : Colors.black87;

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
          'Создать набор',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        controlsBuilder: _buildControls,
        steps: [
          Step(
            title: const Text('Выбор источника'),
            content: _buildSourceSelection(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Карточки'),
            content: _buildCardsPreview(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Настройки'),
            content: _buildSettings(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Готово'),
            content: _buildSummary(),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_currentStep < 3)
            Expanded(
              child: ElevatedButton(
                onPressed: _isGenerating || _isSaving ? null : details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_currentStep == 2 ? 'Создать' : 'Далее'),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSet,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.check),
                label: Text(_isSaving ? 'Сохранение...' : 'Сохранить набор'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0 && _currentStep < 3) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: details.onStepCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Назад'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Откуда создать карточки?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSourceOption(
          SetSource.aiLecture,
          LucideIcons.mic,
          'Из AI-лекции',
          'Создать карточки из записи лекции',
          Colors.blue,
          cardColor,
          textColor,
          subtextColor,
        ),
        const SizedBox(height: 12),
        
        _buildSourceOption(
          SetSource.aiScan,
          LucideIcons.scan,
          'Из AI-конспекта',
          'Создать карточки из сканированного материала',
          Colors.green,
          cardColor,
          textColor,
          subtextColor,
        ),
        const SizedBox(height: 12),
        
        _buildSourceOption(
          SetSource.empty,
          LucideIcons.plus,
          'Пустой набор',
          'Создать карточки вручную с нуля',
          Colors.purple,
          cardColor,
          textColor,
          subtextColor,
        ),
        
        if (_selectedSource != null && _selectedSource != SetSource.empty) ...[
          const SizedBox(height: 20),
          _buildEntrySelector(cardColor, textColor, subtextColor),
        ],
      ],
    );
  }

  Widget _buildSourceOption(
    SetSource source,
    IconData icon,
    String title,
    String description,
    Color color,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    final isSelected = _selectedSource == source;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSource = source;
          _selectedEntry = null;
          _cards = [];
          _selectedCardIndices.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrySelector(Color cardColor, Color textColor, Color? subtextColor) {
    return Consumer<NotebookProvider>(
      builder: (context, provider, child) {
        final entries = provider.entries
            .where((e) => 
                (_selectedSource == SetSource.aiLecture && e.type == EntryType.lecture) ||
                (_selectedSource == SetSource.aiScan && e.type == EntryType.scan))
            .toList();

        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.inbox, color: subtextColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Нет доступных материалов',
                    style: TextStyle(color: subtextColor),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите материал:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            ...entries.take(5).map((entry) {
              final isSelected = _selectedEntry?.id == entry.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedEntry = entry),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            LucideIcons.check,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCardsPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    if (_isGenerating) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Генерация карточек...'),
            ],
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      if (_selectedSource == SetSource.empty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(LucideIcons.sparkles, color: subtextColor, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Заполните название, курс и теги на следующем шаге',
                  style: TextStyle(color: subtextColor, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Затем AI создаст карточки автоматически',
                  style: TextStyle(color: subtextColor?.withOpacity(0.7), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Show dialog to input metadata first
                    await _showMetadataDialog();
                  },
                  icon: const Icon(LucideIcons.wand2),
                  label: const Text('Сгенерировать сейчас'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      
      return Center(
        child: Column(
          children: [
            Icon(LucideIcons.layers, color: subtextColor, size: 64),
            const SizedBox(height: 16),
            Text(
              'Карточки будут сгенерированы автоматически',
              style: TextStyle(color: subtextColor),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Выберите карточки для добавления',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedCardIndices.length == _cards.length) {
                    _selectedCardIndices.clear();
                  } else {
                    _selectedCardIndices.addAll(
                      List.generate(_cards.length, (i) => i),
                    );
                  }
                });
              },
              child: Text(
                _selectedCardIndices.length == _cards.length
                    ? 'Снять все'
                    : 'Выбрать все',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final isSelected = _selectedCardIndices.contains(index);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedCardIndices.add(index);
                        } else {
                          _selectedCardIndices.remove(index);
                        }
                      });
                    },
                    title: Text(
                      card.term,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        card.definition,
                        style: TextStyle(color: subtextColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Название набора',
            hintText: 'Например: Математика - Геометрия',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        TextField(
          controller: _courseController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Курс (необязательно)',
            hintText: 'Например: Математика',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        TextField(
          controller: _tagsController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Теги (через запятую)',
            hintText: 'Например: геометрия, теоремы',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          'Иконка и цвет',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            GestureDetector(
              onTap: _showIconPicker,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedColor, width: 2),
                ),
                child: Icon(_selectedIcon, color: _selectedColor, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.indigo,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.red,
                  Colors.purple,
                ].map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        
        // AI Generation button for empty sets
        if (_selectedSource == SetSource.empty && _cards.isEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      color: const Color(0xFF6366F1),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Генерация AI карточек',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'AI создаст карточки на основе названия, курса и тегов',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () {
                      if (_titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Сначала введите название набора')),
                        );
                        return;
                      }
                      _generateCardsFromMetadata();
                    },
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(LucideIcons.wand2),
                    label: Text(_isGenerating ? 'Генерация...' : 'Сгенерировать карточки'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final selectedCards = _selectedCardIndices.map((i) => _cards[i]).toList();

    return Container(
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_selectedIcon, color: _selectedColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.isEmpty
                          ? 'Без названия'
                          : _titleController.text,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (_courseController.text.isNotEmpty)
                      Text(
                        _courseController.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Icon(LucideIcons.layers, color: subtextColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '${selectedCards.length} карточек',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          
          if (_tagsController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tagsController.text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  void _onStepContinue() async {
    if (_currentStep == 0) {
      // Validate source selection
      if (_selectedSource == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите источник карточек')),
        );
        return;
      }

      if (_selectedSource != SetSource.empty && _selectedEntry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите материал')),
        );
        return;
      }

      // Generate cards (if not empty set)
      if (_selectedSource != SetSource.empty) {
        await _generateCards();
      }
      
      // Always proceed to next step (even with 0 cards)
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // For empty set or if no cards generated, allow to proceed
      if (_selectedSource != SetSource.empty && _cards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сгенерировать карточки. Вы можете создать их вручную позже.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (_selectedCardIndices.isEmpty && _cards.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите хотя бы одну карточку')),
        );
        return;
      }

      // Auto-fill title from entry
      if (_titleController.text.isEmpty && _selectedEntry != null) {
        _titleController.text = _selectedEntry!.title;
      } else if (_titleController.text.isEmpty && _selectedSource == SetSource.empty) {
        _titleController.text = 'Новый набор';
      }

      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      // Validate settings
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите название набора')),
        );
        return;
      }

      setState(() => _currentStep++);
    }
  }

  Future<void> _generateCards() async {
    if (_selectedSource == SetSource.empty) {
      setState(() => _currentStep++);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) throw Exception('User not found');

      List<StudyCard> generatedCards = [];

      if (_selectedSource == SetSource.aiLecture && _selectedEntry != null) {
        if (_selectedEntry!.linkedResourceId == null || _selectedEntry!.linkedResourceId!.isEmpty) {
          print('[CREATE_SET] No linkedResourceId for lecture entry');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Лекция не содержит данных для генерации карточек'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print('[CREATE_SET] Generating cards from lecture: ${_selectedEntry!.linkedResourceId}');
          final result = await _api.generateCardsFromLecture(
            _selectedEntry!.linkedResourceId!,
            user.id,
          );

          print('[CREATE_SET] Lecture cards result: $result');
          
          if (result['success'] == true && result['data'] != null) {
            // Handle double-nested response: {success: true, data: {success: true, data: {cards: [...]}}}
            final dataLevel1 = result['data'];
            final dataLevel2 = dataLevel1 is Map && dataLevel1.containsKey('data') ? dataLevel1['data'] : dataLevel1;
            final cards = dataLevel2['cards'] as List?;
            generatedCards = cards?.map((c) => StudyCard(
              term: c['term'] ?? '',
              definition: c['definition'] ?? '',
            )).toList() ?? [];
            print('[CREATE_SET] Generated ${generatedCards.length} cards from lecture');
          } else {
            print('[CREATE_SET] Failed to generate cards from lecture: ${result['message']}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: ${result['message'] ?? 'Не удалось сгенерировать карточки'}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else if (_selectedSource == SetSource.aiScan && _selectedEntry != null) {
        if (_selectedEntry!.linkedResourceId == null || _selectedEntry!.linkedResourceId!.isEmpty) {
          print('[CREATE_SET] No linkedResourceId for scan entry');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Конспект не содержит данных для генерации карточек'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print('[CREATE_SET] Generating cards from scan: ${_selectedEntry!.linkedResourceId}');
          final result = await _api.generateCardsFromScan(
            _selectedEntry!.linkedResourceId!,
            user.id,
          );

          print('[CREATE_SET] Scan cards result: $result');
          
          if (result['success'] == true && result['data'] != null) {
            // Handle double-nested response: {success: true, data: {success: true, data: {cards: [...]}}}
            final dataLevel1 = result['data'];
            final dataLevel2 = dataLevel1 is Map && dataLevel1.containsKey('data') ? dataLevel1['data'] : dataLevel1;
            final cards = dataLevel2['cards'] as List?;
            generatedCards = cards?.map((c) => StudyCard(
              term: c['term'] ?? '',
              definition: c['definition'] ?? '',
            )).toList() ?? [];
            print('[CREATE_SET] Generated ${generatedCards.length} cards from scan');
          } else {
            print('[CREATE_SET] Failed to generate cards from scan: ${result['message']}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: ${result['message'] ?? 'Не удалось сгенерировать карточки'}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else if (_selectedSource == SetSource.empty) {
        print('[CREATE_SET] Empty set - will allow manual cards or AI generation from title later');
        // Empty set: user will add cards manually, or we can generate from title in step 2
      }

      setState(() {
        _cards = generatedCards;
        _selectedCardIndices.addAll(
          List.generate(generatedCards.length, (i) => i),
        );
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка генерации: $e')),
        );
      }
    }
  }

  void _showIconPicker() {
    final icons = [
      LucideIcons.layers,
      LucideIcons.book,
      LucideIcons.brain,
      LucideIcons.lightbulb,
      LucideIcons.star,
      LucideIcons.target,
      LucideIcons.award,
      LucideIcons.bookmark,
      LucideIcons.flame,
      LucideIcons.zap,
      LucideIcons.heart,
      LucideIcons.coffee,
      LucideIcons.code,
      LucideIcons.beaker,
      LucideIcons.compass,
      LucideIcons.rocket,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите иконку'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              children: icons.map((icon) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == icon
                          ? _selectedColor.withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedIcon == icon
                            ? _selectedColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: _selectedIcon == icon
                          ? _selectedColor
                          : Colors.grey[600],
                      size: 28,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveSet() async {
    setState(() => _isSaving = true);

    try {
      final selectedCards = _selectedCardIndices.map((i) => _cards[i]).toList();
      
      // Parse tags from controller (comma-separated)
      final tags = _tagsController.text.trim().isNotEmpty
          ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];
      
      final studySet = StudySet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        cards: selectedCards,
        icon: _selectedIcon,
        color: _selectedColor,
        createdAt: DateTime.now(),
        tags: tags,
        course: _courseController.text.trim().isNotEmpty ? _courseController.text.trim() : null,
      );

      await StudySetsService().saveStudySet(studySet);
      
      // Проверить достижения
      try {
        final allSets = await StudySetsService().getStudySets();
        await _achievementsService.checkAndUnlockAchievements(
          cardsCount: allSets.length,
        );
      } catch (e) {
        print('[CreateSet] Error checking achievements: $e');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Набор успешно создан!')),
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

  Future<void> _showMetadataDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final titleController = TextEditingController(text: _titleController.text);
    final courseController = TextEditingController(text: _courseController.text);
    final tagsController = TextEditingController(text: _tagsController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Данные для AI генерации',
          style: TextStyle(color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI создаст карточки на основе этих данных:',
                style: TextStyle(color: subtextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Название темы *',
                  labelStyle: TextStyle(color: subtextColor),
                  hintText: 'Например: Алгебра - Квадратные уравнения',
                  hintStyle: TextStyle(color: subtextColor?.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Курс (необязательно)',
                  labelStyle: TextStyle(color: subtextColor),
                  hintText: 'Например: Математика 9 класс',
                  hintStyle: TextStyle(color: subtextColor?.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Теги (через запятую)',
                  labelStyle: TextStyle(color: subtextColor),
                  hintText: 'Например: формулы, теоремы, задачи',
                  hintStyle: TextStyle(color: subtextColor?.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите название темы')),
                );
                return;
              }
              
              _titleController.text = titleController.text.trim();
              _courseController.text = courseController.text.trim();
              _tagsController.text = tagsController.text.trim();
              
              Navigator.pop(context);
              _generateCardsFromMetadata();
            },
            icon: const Icon(LucideIcons.sparkles),
            label: const Text('Сгенерировать'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateCardsFromMetadata() async {
    setState(() => _isGenerating = true);

    try {
      final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
      final user = profileNotifier.user;
      if (user == null) throw Exception('User not found');

      final tags = _tagsController.text.trim().isNotEmpty
          ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      print('[CREATE_SET] Generating cards from metadata: title=${_titleController.text}, course=${_courseController.text}, tags=$tags');

      final result = await _api.generateCardsFromMetadata(
        userId: user.id,
        title: _titleController.text.trim(),
        course: _courseController.text.trim().isNotEmpty ? _courseController.text.trim() : null,
        tags: tags,
      );

      print('[CREATE_SET] Metadata cards result: $result');

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final cards = data['cards'] as List?;
        final generatedCards = cards?.map((c) => StudyCard(
          term: c['term'] ?? '',
          definition: c['definition'] ?? '',
        )).toList() ?? [];

        print('[CREATE_SET] Generated ${generatedCards.length} cards from metadata');

        if (mounted) {
          setState(() {
            _cards = generatedCards;
            _selectedCardIndices.addAll(List.generate(generatedCards.length, (i) => i));
            _isGenerating = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Сгенерировано ${generatedCards.length} карточек!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        print('[CREATE_SET] Failed to generate cards from metadata: ${result['message']}');
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: ${result['message'] ?? 'Не удалось сгенерировать карточки'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[CREATE_SET] Exception generating cards from metadata: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

