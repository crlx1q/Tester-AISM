import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/study_set.dart';
import '../services/study_sets_service.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';

class CreateSetPage extends StatefulWidget {
  const CreateSetPage({Key? key}) : super(key: key);

  @override
  State<CreateSetPage> createState() => _CreateSetPageState();
}

class _CreateSetPageState extends State<CreateSetPage> {
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _termController = TextEditingController();
  final _definitionController = TextEditingController();
  final List<StudyCard> _cards = [];
  final _formKey = GlobalKey<FormState>();
  bool _isGeneratingAI = false;
  bool _isLoading = false;
  final ApiService _api = ApiService();

  void _addCard() {
    final term = _termController.text.trim();
    final definition = _definitionController.text.trim();

    if (term.isNotEmpty && definition.isNotEmpty) {
      setState(() {
        _cards.add(StudyCard(term: term, definition: definition));
        _termController.clear();
        _definitionController.clear();
      });
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  void _removeCard(int index) {
    setState(() {
      _cards.removeAt(index);
    });
  }

  Future<void> _generateWithAI() async {
    final topic = _topicController.text.trim();
    
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите тему для генерации карточек')),
      );
      return;
    }
    
    setState(() => _isGeneratingAI = true);
    
    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) throw Exception('User not found');
      
      final result = await _api.aiChat(
        userId: userId,
        message: 'Создай 5 карточек для изучения по теме "$topic". Верни JSON в формате: {"cards": [{"term": "...", "definition": "..."}, ...]}. Только JSON без объяснений.',
        history: [],
        attachments: [],
      );
      
      if (result['success'] == true && result['data'] != null) {
        final responseText = result['data']['text'] ?? '';
        
        // Extract JSON from response
        final jsonStart = responseText.indexOf('{');
        final jsonEnd = responseText.lastIndexOf('}') + 1;
        
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          try {
            final jsonStr = responseText.substring(jsonStart, jsonEnd);
            final Map<String, dynamic> jsonData = Map<String, dynamic>.from(
              (jsonDecode(jsonStr) as Map).cast<String, dynamic>()
            );
            
            if (jsonData['cards'] != null) {
              final List<dynamic> aiCards = jsonData['cards'];
              
              setState(() {
                for (var card in aiCards) {
                  if (card['term'] != null && card['definition'] != null) {
                    _cards.add(StudyCard(
                      term: card['term'].toString(),
                      definition: card['definition'].toString(),
                    ));
                  }
                }
                if (_titleController.text.isEmpty) {
                  _titleController.text = topic;
                }
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Добавлено ${aiCards.length} карточек!')),
              );
            }
          } catch (e) {
            print('JSON parse error: $e');
            throw Exception('Не удалось разобрать ответ AI');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка генерации: $e')),
      );
    } finally {
      setState(() => _isGeneratingAI = false);
    }
  }
  
  Future<void> _saveSet() async {
    final title = _titleController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, введите название набора')),
      );
      return;
    }

    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну карточку')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studySet = StudySet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        cards: _cards,
        icon: LucideIcons.star,
        color: Colors.indigo,
        createdAt: DateTime.now(),
      );

      await StudySetsService().saveStudySet(studySet);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Набор "$title" успешно создан!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _titleController.text.trim().isNotEmpty && _cards.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Создать набор',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Название набора (напр. "История Др. Рима")',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // AI Generation section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Генератор карточек',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _topicController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Введите тему для генерации (например: "Фотосинтез")',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isGeneratingAI ? null : _generateWithAI,
                            icon: _isGeneratingAI 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                  ),
                                )
                              : const Icon(LucideIcons.wand2, color: Colors.black87),
                            label: Text(
                              _isGeneratingAI ? 'Генерирую...' : 'Сгенерировать карточки',
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card input section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[800]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Или добавьте карточки вручную',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        // Term input
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF262626),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _termController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Термин',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Definition input
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF262626),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _definitionController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Определение',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Add card button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addCard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Добавить карточку',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Cards list
                  if (_cards.isNotEmpty) ...[
                    Text(
                      'Карточки (${_cards.length})',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_cards.length, (index) {
                      final card = _cards[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.term,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    card.definition.length > 50
                                        ? '${card.definition.substring(0, 50)}...'
                                        : card.definition,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeCard(index),
                              icon: Icon(
                                LucideIcons.x,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border(
                top: BorderSide(color: Colors.grey[900]!, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSave && !_isLoading ? _saveSet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave 
                      ? const Color(0xFF10B981)
                      : Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: canSave ? 8 : 0,
                  shadowColor: const Color(0xFF10B981).withOpacity(0.3),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Сохранить набор',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _termController.dispose();
    _definitionController.dispose();
    super.dispose();
  }
}
