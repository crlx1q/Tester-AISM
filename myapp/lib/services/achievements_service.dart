import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../services/api_service.dart';
import '../services/user_prefs.dart';

class AchievementsService {
  static const String _key = 'user_achievements';
  final ApiService _apiService = ApiService();
  
  Future<Map<String, Achievement>> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    
    if (data == null) {
      // Создать все достижения как заблокированные
      final achievements = <String, Achievement>{};
      for (final achievement in Achievements.all) {
        achievements[achievement.id] = achievement;
      }
      await _saveAchievements(achievements);
      return achievements;
    }
    
    final json = jsonDecode(data) as Map<String, dynamic>;
    final achievements = <String, Achievement>{};
    
    for (final entry in json.entries) {
      achievements[entry.key] = Achievement.fromJson(entry.value as Map<String, dynamic>);
    }
    
    // Добавить новые достижения, если появились
    for (final achievement in Achievements.all) {
      if (!achievements.containsKey(achievement.id)) {
        achievements[achievement.id] = achievement;
      }
    }
    
    return achievements;
  }
  
  Future<void> _saveAchievements(Map<String, Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{};
    for (final entry in achievements.entries) {
      json[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_key, jsonEncode(json));
  }
  
  Future<List<Achievement>> getAllAchievements() async {
    // Сначала загрузить локально
    final achievements = await _loadAchievements();
    
    // Попробовать синхронизировать с сервером
    try {
      final userId = await UserPrefs.getUserId();
      if (userId != null) {
        final serverResult = await _apiService.getAchievements(userId);
        if (serverResult['success'] == true && serverResult['data'] != null) {
          final serverAchievements = (serverResult['data'] as List)
              .cast<Map<String, dynamic>>();
          
          // Обновить локальные достижения данными с сервера
          for (final serverAch in serverAchievements) {
            final achievementId = serverAch['id']?.toString().split('_')[0] ?? '';
            if (achievementId.isNotEmpty && achievements.containsKey(achievementId)) {
              final localAch = achievements[achievementId]!;
              // Обновить только если серверное достижение разблокировано
              if (serverAch['completed'] == true && !localAch.isUnlocked) {
                achievements[achievementId] = localAch.copyWith(
                  isUnlocked: true,
                  unlockedAt: serverAch['completedAt'] != null
                      ? DateTime.parse(serverAch['completedAt'])
                      : DateTime.now(),
                );
              }
            }
          }
          
          // Сохранить обновленные локальные данные
          await _saveAchievements(achievements);
          
          // Массово сохранить все локальные достижения на сервер
          final achievementsList = achievements.values
              .where((a) => a.isUnlocked)
              .map((a) => {
                'id': a.id,
                'type': a.type.toString().split('.').last,
                'name': a.name,
                'description': a.description,
                'icon': a.icon,
                'color': a.color.value,
                'isUnlocked': a.isUnlocked,
                'unlockedAt': a.unlockedAt?.toIso8601String(),
              })
              .toList();
          
          if (achievementsList.isNotEmpty) {
            await _apiService.saveAchievementsBatch(
              userId: userId,
              achievements: achievementsList,
            );
          }
        }
      }
    } catch (e) {
      print('[AchievementsService] Error syncing from server: $e');
      // Продолжаем с локальными данными
    }
    
    return achievements.values.toList()
      ..sort((a, b) {
        if (a.isUnlocked && !b.isUnlocked) return -1;
        if (!a.isUnlocked && b.isUnlocked) return 1;
        if (a.unlockedAt != null && b.unlockedAt != null) {
          return b.unlockedAt!.compareTo(a.unlockedAt!);
        }
        return a.name.compareTo(b.name);
      });
  }
  
  Future<List<Achievement>> getUnlockedAchievements() async {
    final all = await getAllAchievements();
    return all.where((a) => a.isUnlocked).toList();
  }
  
  Future<Achievement?> unlockAchievement(String id) async {
    final achievements = await _loadAchievements();
    final achievement = achievements[id];
    
    if (achievement == null || achievement.isUnlocked) {
      return null;
    }
    
    final updated = achievement.copyWith(
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );
    
    achievements[id] = updated;
    await _saveAchievements(achievements);
    
    // Синхронизировать с сервером
    try {
      final userId = await UserPrefs.getUserId();
      if (userId != null) {
        await _apiService.saveAchievement(
          userId: userId,
          achievementId: id,
          type: achievement.type.toString().split('.').last,
          name: achievement.name,
          description: achievement.description,
          icon: achievement.icon,
          color: achievement.color.value,
          isUnlocked: true,
          unlockedAt: DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      print('[AchievementsService] Error syncing to server: $e');
      // Не прерываем процесс если сервер недоступен
    }
    
    return updated;
  }
  
  Future<void> checkAndUnlockAchievements({
    int? quizCount,
    int? chatCount,
    int? streakDays,
    int? cardsCount,
    int? studyMinutes,
    int? maxLevel,
    int? quizScore, // Для достижения "Идеально!"
  }) async {
    final achievements = await _loadAchievements();
    final newlyUnlocked = <Achievement>[];
    
    for (final achievement in achievements.values) {
      if (achievement.isUnlocked) continue;
      
      bool shouldUnlock = false;
      
      switch (achievement.type) {
        case AchievementType.quiz:
          // Для quiz_perfect нужен score=100
          if (achievement.id == 'quiz_perfect') {
            if (quizScore != null && quizScore >= 100) {
              shouldUnlock = true;
            }
          } else if (quizCount != null && quizCount >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
        case AchievementType.chat:
          if (chatCount != null && chatCount >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
        case AchievementType.streak:
          if (streakDays != null && streakDays >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
        case AchievementType.cards:
          if (cardsCount != null && cardsCount >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
        case AchievementType.studyTime:
          if (studyMinutes != null && studyMinutes >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
        case AchievementType.level:
          if (maxLevel != null && maxLevel >= achievement.requiredValue) {
            shouldUnlock = true;
          }
          break;
      }
      
      if (shouldUnlock) {
        final unlocked = await unlockAchievement(achievement.id);
        if (unlocked != null) {
          newlyUnlocked.add(unlocked);
        }
      }
    }
    
    // Сохранить все разблокированные достижения на сервер одним запросом
    if (newlyUnlocked.isNotEmpty) {
      try {
        final userId = await UserPrefs.getUserId();
        if (userId != null) {
          final achievementsList = newlyUnlocked.map((a) => {
            'id': a.id,
            'type': a.type.toString().split('.').last,
            'name': a.name,
            'description': a.description,
            'icon': a.icon,
            'color': a.color.value,
            'isUnlocked': true,
            'unlockedAt': a.unlockedAt?.toIso8601String(),
          }).toList();
          
          await _apiService.saveAchievementsBatch(
            userId: userId,
            achievements: achievementsList,
          );
          
          print('[AchievementsService] Synced ${newlyUnlocked.length} newly unlocked achievements to server');
        }
      } catch (e) {
        print('[AchievementsService] Error syncing batch to server: $e');
      }
    }
    
    // Вернуть список новых достижений (можно использовать для уведомлений)
    return;
  }
  
  Future<int> getProgress(String achievementId) async {
    final achievements = await _loadAchievements();
    final achievement = achievements[achievementId];
    if (achievement == null || achievement.isUnlocked) return 100;
    
    // Возвращает процент прогресса (0-100)
    // Здесь можно добавить логику получения текущего значения
    return 0;
  }
}

