import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';
import '../services/ai_history_service.dart';
import '../services/achievements_service.dart';

class TutorPage extends StatefulWidget {
  const TutorPage({super.key});

  @override
  State<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends State<TutorPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final AiHistoryService _history = AiHistoryService();
  final AchievementsService _achievementsService = AchievementsService();
  final ImagePicker _picker = ImagePicker();

  // Each message: { sender: 'user'|'bot', text: String, attachments: [ { mimeType, data } ] }
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pendingAttachments = [];
  bool _isLoading = false;
  bool _isSavingSession = false;
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _addWelcomeMessage();
  }

  @override
  void dispose() async {
    // Report study minutes before disposing
    if (_sessionStartTime != null && _messages.length > 1) {
      final studyMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
      if (studyMinutes > 0) {
        try {
          final userId = await UserPrefs.getUserId();
          if (userId != null) {
            await _api.reportActivity(
              userId: userId,
              type: 'chat',
              minutes: studyMinutes,
            );
            print('[TUTOR] Reported $studyMinutes study minutes');
          }
        } catch (e) {
          print('[TUTOR] Failed to report study minutes: $e');
        }
      }
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add({
      'sender': 'bot',
      'text': 'Привет! 👋 Я Айдар, твой AI-наставник. Я помню твой прогресс и могу помочь с учебой, объяснить сложные темы, решить задачи или проверить твои знания. О чем хочешь поговорить?',
      'attachments': const [],
    });
  }
  
  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить чат'),
        content: const Text('Вы уверены, что хотите очистить историю чата? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      setState(() {
        _messages.clear();
        _pendingAttachments.clear();
      });
      _addWelcomeMessage();
      _scrollToBottom();
      
      // Очистить локальную историю
      await _history.getChat().then((history) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('ai_history_chat');
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': message,
        'attachments': List<Map<String, dynamic>>.from(_pendingAttachments),
      });
      _isLoading = true;
      _pendingAttachments = [];
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не найден');
      }

      // Build history for server (exclude the last message which is the current one)
      final previous = _messages.length > 1 ? _messages.sublist(0, _messages.length - 1) : <Map<String, dynamic>>[];
      final history = previous.map((m) => {
            'sender': m['sender'],
            'text': m['text'],
            if ((m['attachments'] as List?)?.isNotEmpty == true) 'attachments': m['attachments'],
          }).toList();

      // Extract current attachments from last message so server can include them correctly
      final currentAttachments = (_messages.isNotEmpty && (_messages.last['attachments'] as List?)?.isNotEmpty == true)
          ? List<Map<String, dynamic>>.from(_messages.last['attachments'] as List)
          : const <Map<String, dynamic>>[];

      print('[AI Chat] Sending message to server...');
      final resp = await _api.aiChat(
        userId: userId,
        message: message,
        history: history,
        attachments: currentAttachments,
      );
      
      print('[AI Chat] Response received. Success: ${resp['success']}');
      
      if (resp['success'] != true) {
        final errorMsg = resp['message'] ?? 'Неизвестная ошибка сервера';
        print('[AI Chat] Server error: $errorMsg');
        throw Exception(errorMsg);
      }

      final data = resp['data'] ?? {};
      final aiText = (data['text'] ?? '').toString().trim();
      
      if (aiText.isEmpty) {
        print('[AI Chat] Warning: AI returned empty response');
        throw Exception('AI вернул пустой ответ. Попробуйте переформулировать вопрос.');
      }

      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': aiText,
            'attachments': const [],
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }

      // Save local history
      await _history.addChat({
        'userMessage': message,
        'aiResponse': aiText,
        'attachments': currentAttachments,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Save AI meta to prefs if present
      if (resp['ai'] != null) {
        await UserPrefs.updateAiMeta(resp['ai'] as Map<String, dynamic>?);
      }
      
      // Проверить достижения для чата
      final chatHistory = await _history.getChat();
      await _achievementsService.checkAndUnlockAchievements(
        chatCount: chatHistory.length,
      );
    } catch (e) {
      print('[AI Chat] Error occurred: $e');
      
      String errorMessage;
      final errorStr = e.toString();
      
      if (errorStr.contains('Failed host lookup') || errorStr.contains('Connection')) {
        errorMessage = 'Не удалось подключиться к серверу. Проверьте интернет-соединение.';
      } else if (errorStr.contains('TimeoutException') || errorStr.contains('timed out')) {
        errorMessage = 'Превышено время ожидания ответа. Попробуйте еще раз.';
      } else if (errorStr.contains('Пользователь не найден')) {
        errorMessage = 'Ошибка авторизации. Пожалуйста, войдите в приложение заново.';
      } else if (errorStr.contains('лимит') || errorStr.contains('limit')) {
        errorMessage = 'Достигнут лимит использования AI. Попробуйте позже или обновите подписку.';
      } else if (errorStr.contains('AI вернул пустой ответ')) {
        errorMessage = 'AI не смог сформировать ответ. Попробуйте переформулировать вопрос.';
      } else {
        errorMessage = 'Извините, не удалось получить ответ. ${errorStr.length < 100 ? errorStr : "Ошибка сервера."}';
      }
      
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': errorMessage,
            'attachments': const [],
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _attachImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _pendingAttachments.add({
          'type': 'image',
          'mimeType': 'image/${x.name.split('.').last.toLowerCase() == 'png' ? 'png' : 'jpeg'}',
          'data': b64,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка добавления фото: $e')));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveSession() async {
    if (_isSavingSession || _messages.length <= 1) return;

    setState(() => _isSavingSession = true);

    try {
      final userId = await UserPrefs.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не найден');
      }

      // Extract session summary from messages
      final goals = ['Обсудить: ${_messages[1]['text'] ?? 'неизвестно'}'];
      final keyTakeaways = _messages
          .where((m) => m['sender'] == 'bot')
          .take(3)
          .map((m) => m['text'].toString().substring(0, m['text'].toString().length > 100 ? 100 : m['text'].toString().length))
          .toList();
      
      await _api.createAiSession(
        userId: userId,
        goals: goals,
        keyTakeaways: keyTakeaways,
        homework: [],
        suggestedNextSteps: ['Продолжить практику', 'Повторить материал'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сессия сохранена в AI Notebook!')),
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
        setState(() => _isSavingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.grey.shade800;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.brainCircuit,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Айдар',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ваш AI-наставник',
                  style: TextStyle(
                    color: isDark ? Colors.greenAccent.shade100 : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical, color: textColor),
            onSelected: (value) async {
              switch (value) {
                case 'save':
                  await _saveSession();
                  break;
                case 'clear':
                  await _clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_messages.length > 1)
                PopupMenuItem(
                  value: 'save',
                  enabled: !_isSavingSession,
                  child: Row(
                    children: [
                      const Icon(LucideIcons.save, size: 18),
                      const SizedBox(width: 12),
                      const Text('Сохранить чат'),
                      if (_isSavingSession) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 18),
                    SizedBox(width: 12),
                    Text('Очистить чат'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator(cardColor);
                }

                final message = _messages[index];
                final isUser = message['sender'] == 'user';

                return _buildMessageBubble(
                  message['text'] ?? '',
                  isUser,
                  textColor,
                  cardColor,
                  attachments: (message['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attached images preview
                  if (_pendingAttachments.isNotEmpty) ...[
                    Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingAttachments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final attachment = _pendingAttachments[index];
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Image.memory(
                                  base64Decode(attachment['data'] as String),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _pendingAttachments.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Спросите что-нибудь...',
                            hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1F2937) : cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1F2937) : cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: IconButton(
                          onPressed: _attachImage,
                          icon: Icon(
                            LucideIcons.paperclip,
                            color: _pendingAttachments.isNotEmpty 
                              ? const Color(0xFF6366F1) 
                              : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _isLoading ? null : _sendMessage,
                          icon: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, Color textColor, Color cardColor, {List<Map<String, dynamic>> attachments = const []}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigo : cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachments.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attachments.map((a) => Container(
                  width: 120,
                  height: 80,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.memory(
                    base64Decode(a['data'] as String),
                    fit: BoxFit.cover,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (isUser)
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              )
            else
              MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  em: TextStyle(
                    color: textColor,
                    fontStyle: FontStyle.italic,
                  ),
                  code: TextStyle(
                    backgroundColor: cardColor,
                    color: textColor,
                    fontFamily: 'monospace',
                  ),
                  listBullet: TextStyle(color: textColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(Color cardColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return _TypingDot(index: index, isLoading: _isLoading);
  }
}

class _TypingDot extends StatefulWidget {
  final int index;
  final bool isLoading;

  const _TypingDot({required this.index, required this.isLoading});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final isActive = (widget.index == 0 && value < 0.33) ||
                        (widget.index == 1 && value >= 0.33 && value < 0.66) ||
                        (widget.index == 2 && value >= 0.66);
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withOpacity(isActive ? 1.0 : 0.4),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
