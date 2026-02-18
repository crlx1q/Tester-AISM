import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/hero_section.dart';

class UserPrefs {
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString == null) return null;
    try {
      final data = jsonDecode(userDataString);
      final id = data['id'];
      if (id is int) return id;
      return int.tryParse('$id');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getRawUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString == null) return null;
    try {
      return jsonDecode(userDataString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateAiMeta(Map<String, dynamic>? ai) async {
    if (ai == null) {
      print('[UserPrefs] ❌ updateAiMeta: ai is null');
      return;
    }

    print('[UserPrefs] 📝 updateAiMeta called with: ${ai.toString()}');
    final streak = ai['streak'] as Map?;
    if (streak != null) {
      print(
          '[UserPrefs] 🔥 Streak data: current=${streak['current']}, lastActiveDate=${streak['lastActiveDate']}');
    } else {
      print('[UserPrefs] ⚠️ No streak in ai meta!');
    }

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString == null) {
      print('[UserPrefs] ❌ userData not found in SharedPreferences');
      return;
    }

    try {
      final data = jsonDecode(userDataString) as Map<String, dynamic>;
      data['ai'] = ai;
      await prefs.setString('userData', jsonEncode(data));
      print('[UserPrefs] ✅ Updated userData in SharedPreferences');

      // Уведомляем HeroSection об обновлении streak
      if (heroSectionKey.currentState == null) {
        print(
            '[UserPrefs] ⚠️ WARNING: heroSectionKey.currentState is NULL! HeroSection not mounted or key not set');
      } else {
        print('[UserPrefs] 🎯 Notifying HeroSection to reload streak...');
        await heroSectionKey.currentState!.reloadStreak();
        print('[UserPrefs] ✅ HeroSection reloadStreak completed');
      }
    } catch (e) {
      print('[UserPrefs] ❌ Error updating ai meta: $e');
    }
  }

  static Future<Map<String, dynamic>?> getAiMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString == null) return null;
    try {
      final data = jsonDecode(userDataString) as Map<String, dynamic>;
      return data['ai'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
