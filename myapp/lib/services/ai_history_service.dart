import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiHistoryService {
  static const String _scanKey = 'ai_history_scan';
  static const String _voiceKey = 'ai_history_voice';
  static const String _chatKey = 'ai_history_chat';

  // Generic helpers
  Future<List<Map<String, dynamic>>> _getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> _push(String key, Map<String, dynamic> entry, {int max = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.insert(0, jsonEncode(entry));
    if (list.length > max) {
      list.length = max;
    }
    await prefs.setStringList(key, list);
  }

  // Scan
  Future<void> addScan(Map<String, dynamic> entry) => _push(_scanKey, entry, max: 30);
  Future<List<Map<String, dynamic>>> getScan() => _getList(_scanKey);

  // Voice
  Future<void> addVoice(Map<String, dynamic> entry) => _push(_voiceKey, entry, max: 30);
  Future<List<Map<String, dynamic>>> getVoice() => _getList(_voiceKey);

  // Chat
  Future<void> addChat(Map<String, dynamic> entry) => _push(_chatKey, entry, max: 100);
  Future<List<Map<String, dynamic>>> getChat() => _getList(_chatKey);
}
