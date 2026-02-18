import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/profile_notifier.dart';
import '../services/theme_service.dart';
import '../services/user_prefs.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import '../widgets/beta_badge.dart';
import '../widgets/premium_modal.dart';
import 'premium_management_page.dart';
import 'profile_settings_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onSignedOut;
  const ProfilePage({super.key, required this.onSignedOut});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  final ApiService _apiService = ApiService();
  bool _isUpdatingAvatar = false;
  final ProfileNotifier _profileNotifier = ProfileNotifier();
  final ThemeService _themeService = ThemeService();
  int _aiStreakCurrent = 0;
  int _aiStreakLongest = 0;
  bool _aiActiveToday = false;
  final AchievementsService _achievementsService = AchievementsService();
  List<Achievement> _achievements = [];
  bool _isLoadingAchievements = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAchievements();
    _themeService.addListener(_onThemeChanged);
  }
  
  Future<void> _loadAchievements() async {
    setState(() => _isLoadingAchievements = true);
    try {
      final achievements = await _achievementsService.getAllAchievements();
      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoadingAchievements = false;
        });
      }
    } catch (e) {
      print('[Profile] Error loading achievements: $e');
      if (mounted) {
        setState(() => _isLoadingAchievements = false);
      }
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      final storedUser = User.fromSharedPreferences(userDataString);
      if (mounted) {
        setState(() {
          _user = storedUser;
        });
      }

      if (storedUser != null) {
        _profileNotifier.updateUser(storedUser);
        await _refreshUserFromServer(storedUser.id);
      }
    }
  }

  Future<void> _refreshUserFromServer(int userId) async {
    try {
      final result = await _apiService.getUserProfile(userId);
      if (result['success']) {
        final updatedUser = User.fromJson(result['data']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(updatedUser.toJson()));

        if (mounted) {
          setState(() {
            _user = updatedUser;
          });
        }

        _profileNotifier.updateUser(updatedUser);
        _refreshAiDashboard();
      }
    } catch (e) {
      // Игнорируем ошибки - покажем локальные данные
      debugPrint('Не удалось обновить профиль: $e');
    }
  }

  Future<void> _refreshAiDashboard() async {
    final userId = _user?.id ?? await UserPrefs.getUserId();
    if (userId == null) return;
    try {
      final result = await _apiService.getAiDashboard(userId);
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final streak = data['streak'] as Map<String, dynamic>?;
        final current = streak != null
            ? (streak['current'] as int? ??
                int.tryParse('${streak['current']}') ??
                0)
            : 0;
        final longest = streak != null
            ? (streak['longest'] as int? ??
                int.tryParse('${streak['longest']}') ??
                0)
            : 0;
        final lastActiveStr =
            streak != null ? (streak['lastActiveDate'] as String?) : null;
        bool activeToday = false;
        if (lastActiveStr != null) {
          final last = DateTime.tryParse(lastActiveStr)?.toLocal();
          final now = DateTime.now();
          if (last != null &&
              last.year == now.year &&
              last.month == now.month &&
              last.day == now.day) {
            activeToday = true;
          }
        }
        if (mounted) {
          setState(() {
            _aiStreakCurrent = current;
            _aiStreakLongest = longest;
            _aiActiveToday = activeToday;
          });
        }
      }
    } catch (e) {
      debugPrint('Не удалось получить streak: $e');
    }
  }

  Future<void> _updateAvatar() async {
    if (_user == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _isUpdatingAvatar = true;
      });

      try {
        // Конвертируем изображение в base64
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        final avatarData = 'data:image/jpeg;base64,$base64Image';

        // Отправляем на сервер
        final result = await _apiService.updateAvatar(_user!.id, avatarData);

        if (result['success']) {
          // Обновляем локальные данные пользователя
          final updatedUser = User.fromJson(result['data']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(updatedUser.toJson()));

          setState(() {
            _user = updatedUser;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аватарка обновлена!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: ${result['message']}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки: $e')),
          );
        }
      } finally {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _openProfileSettings() async {
    if (_user == null) return;

    final result = await Navigator.of(context).push<User>(
      MaterialPageRoute(
        builder: (context) => ProfileSettingsPage(
          user: _user!,
          onUserUpdated: (updatedUser) {
            // Этот callback будет вызван из настроек при обновлении данных
          },
        ),
      ),
    );

    // Если пользователь был обновлен, перезагружаем данные
    if (result != null) {
      setState(() {
        _user = result;
      });
    } else {
      // В любом случае перезагружаем данные из локального хранилища
      await _loadUserData();
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1f2937);
    final subtextColor =
        isDarkMode ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);
    final cardColor =
        isDarkMode ? const Color(0xFF1f2937) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF374151) : const Color(0xFFe5e7eb);

    return Scaffold(
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text('Профиль',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 32),
                  _buildProfileInfo(textColor),
                  const SizedBox(height: 32),
                  _buildAchievements(cardColor, textColor, subtextColor, isDarkMode),
                  const SizedBox(height: 32),
                  _buildPremiumSection(cardColor, textColor, isDarkMode),
                  const SizedBox(height: 32),
                  _buildSettingsList(
                      cardColor, borderColor, textColor, subtextColor, isDarkMode),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileInfo(Color textColor) {
    final avatarText =
        _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : '';
    final subtextColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    final bool hasPro = _user?.pro?.status == true;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 48,
                      backgroundImage: MemoryImage(
                        base64Decode(_user!.avatarUrl!.split(
                            ',')[1]), // Убираем data:image/jpeg;base64, префикс
                      ),
                    )
                  : CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(avatarText,
                          style: TextStyle(
                              fontSize: 48, color: Colors.indigo.shade800)),
                    ),
              Positioned(
                bottom: 0,
                right: -4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.indigo,
                  child: _isUpdatingAvatar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(LucideIcons.edit3,
                              size: 16, color: Colors.white),
                          onPressed: () => _openProfileSettings(),
                        ),
                ),
              ),
              // Pro badge if user has Pro
              if (hasPro)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.crown,
                        size: 16, color: Colors.black),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              Text(
                _user!.name,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
              // Pro badge next to name
              if (hasPro)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.crown, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text('PRO',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _aiActiveToday
                      ? const Color(0xFFFFEDD5)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flame,
                        size: 16,
                        color: _aiActiveToday
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text('$_aiStreakCurrent',
                        style: TextStyle(
                            color: _aiActiveToday
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (_user!.badges.isNotEmpty)
                UserBadges(
                  badges: _user!.badges,
                  iconSize: 22,
                  spacing: 8,
                ),
            ],
          ),
          Text(_user!.email,
              style: TextStyle(fontSize: 16, color: subtextColor)),
          const SizedBox(height: 4),
          Text('ID: ${_user!.uid}',
              style: TextStyle(fontSize: 14, color: subtextColor)),
        ],
      ),
    );
  }

  Widget _buildAchievements(
      Color cardColor, Color textColor, Color subtextColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Достижения',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: subtextColor)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Бейджи
              Text('Твои бейджи',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(height: 12),
              if (_user!.badges.isEmpty)
                Text('Пока нет бейджей — всё впереди!',
                    style: TextStyle(color: subtextColor)),
              if (_user!.badges.isNotEmpty)
                UserBadges(
                  badges: _user!.badges,
                  iconSize: 28,
                  spacing: 12,
                ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Новые достижения
              Text('Мои достижения',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(height: 12),
              
              if (_isLoadingAchievements)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final unlockedCount = _achievements.where((a) => a.isUnlocked).length;
                    final totalCount = _achievements.length;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Разблокировано: $unlockedCount из $totalCount',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Прогресс бар
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: totalCount > 0 ? unlockedCount / totalCount : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Список достижений (сетка)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _achievements.length,
                          itemBuilder: (context, index) {
                            final achievement = _achievements[index];
                            return _buildAchievementCard(
                              achievement,
                              cardColor,
                              textColor,
                              subtextColor,
                              isDarkMode,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.flame,
                        color: _aiActiveToday
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Стрик',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                          Text(
                              'Текущий: $_aiStreakCurrent · Рекорд: $_aiStreakLongest',
                              style: TextStyle(color: subtextColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAchievementCard(
    Achievement achievement,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
  ) {
    final isUnlocked = achievement.isUnlocked;
    
    return Tooltip(
      message: achievement.name,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? achievement.color.withOpacity(0.1)
              : (isDarkMode ? const Color(0xFF111827) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked
                ? achievement.color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconData(achievement.icon),
              size: 28,
              color: isUnlocked ? achievement.color : subtextColor,
            ),
            const SizedBox(height: 6),
            Text(
              achievement.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? textColor : subtextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isUnlocked && achievement.unlockedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  LucideIcons.checkCircle2,
                  size: 12,
                  color: achievement.color,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  IconData _getIconData(String iconName) {
    // Маппинг названий иконок на IconData
    switch (iconName) {
      case 'sparkles': return LucideIcons.sparkles;
      case 'award': return LucideIcons.award;
      case 'star': return LucideIcons.star;
      case 'messageCircle': return LucideIcons.messageCircle;
      case 'messagesSquare': return LucideIcons.messagesSquare;
      case 'flame': return LucideIcons.flame;
      case 'layers': return LucideIcons.layers;
      case 'archive': return LucideIcons.archive;
      case 'clock': return LucideIcons.clock;
      case 'timer': return LucideIcons.timer;
      case 'trendingUp': return LucideIcons.trendingUp;
      case 'crown': return LucideIcons.crown;
      default: return LucideIcons.award;
    }
  }

  Widget _buildPremiumSection(Color cardColor, Color textColor, bool isDarkMode) {
    final bool hasPro = _user?.pro?.status == true;
    final proEndDate = _user?.pro?.endDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Premium',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: hasPro
                ? Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.35),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (hasPro && proEndDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.crown, color: Colors.white),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Premium активен',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text('До ${_formatDate(proEndDate)}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildPremiumFeature(
                  LucideIcons.image, '100 фото в день', textColor,
                  isActive: hasPro),
              _buildPremiumFeature(
                  LucideIcons.mic, '20 записей по 2 часа ИИ', textColor,
                  isActive: hasPro),
              _buildPremiumFeature(
                  LucideIcons.fileDown, 'Экспорт в PDF', textColor,
                  isActive: hasPro),
              _buildPremiumFeature(
                  LucideIcons.messageSquare, 'Telegram бот', textColor,
                  isActive: hasPro),
              _buildPremiumFeature(
                  LucideIcons.lightbulb, 'AI Insights', textColor,
                  isActive: hasPro),
              _buildPremiumFeature(LucideIcons.zap, 'Приоритет к ИИ', textColor,
                  isLast: true, isActive: hasPro),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: hasPro
              ? OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PremiumManagementPage(user: _user),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.settings, size: 20),
                  label: const Text('Управление подпиской',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    side:
                        const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () => PremiumModal.show(context),
                  icon: const Icon(LucideIcons.crown,
                      size: 20, color: Colors.white),
                  label: const Text('Разблокировать Premium',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 8,
                    shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                  ),
                ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildPremiumFeature(IconData icon, String text, Color textColor,
      {bool isLast = false, bool isActive = false}) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0),
        child: Row(
          children: [
            Icon(icon,
                color: isActive
                    ? Colors.amber
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                size: 20),
            const SizedBox(width: 12),
            Text(text,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
            const Spacer(),
            Icon(
              isActive ? LucideIcons.checkCircle : LucideIcons.lock,
              size: 16,
              color: isActive ? const Color(0xFF10B981) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(
      Color cardColor, Color borderColor, Color textColor, Color subtextColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Настройки',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: subtextColor)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.0 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                  'Настройки профиля',
                  Icon(LucideIcons.chevronRight, color: subtextColor),
                  borderColor,
                  textColor,
                  onTap: _openProfileSettings),
              _buildSettingsItem(
                  'Тёмная тема',
                  Switch(
                      value: isDarkMode,
                      onChanged: (val) async {
                        await _themeService.toggleDarkMode(val);
                      },
                      activeColor: Colors.indigo),
                  borderColor,
                  textColor),
              _buildSettingsItem(
                  'Цветовые схемы',
                  Icon(LucideIcons.chevronRight, color: subtextColor),
                  borderColor,
                  textColor,
                  onTap: _showColorSchemesDialog),
              _buildSettingsItem(
                  'Помощь и поддержка',
                  Icon(LucideIcons.chevronRight, color: subtextColor),
                  borderColor,
                  textColor,
                  onTap: _showHelpAndSupport),
              _buildSettingsItem(
                  'Интеграция с Telegram',
                  Icon(LucideIcons.chevronRight, color: subtextColor),
                  null,
                  textColor,
                  onTap: _showTelegramIntegration),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _logout,
          child: const Text('Выйти из аккаунта',
              style: TextStyle(color: Colors.red, fontSize: 16)),
        )
      ],
    );
  }

  void _showColorSchemesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Цветовые схемы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto, color: Colors.blue),
              title: const Text('Системная'),
              onTap: () async {
                await _themeService.setThemeMode(ThemeMode.system);
                if (mounted) Navigator.pop(context);
              },
              selected: _themeService.themeMode == ThemeMode.system,
            ),
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.amber),
              title: const Text('Светлая'),
              onTap: () async {
                await _themeService.setThemeMode(ThemeMode.light);
                if (mounted) Navigator.pop(context);
              },
              selected: _themeService.themeMode == ThemeMode.light,
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.indigo),
              title: const Text('Тёмная'),
              onTap: () async {
                await _themeService.setThemeMode(ThemeMode.dark);
                if (mounted) Navigator.pop(context);
              },
              selected: _themeService.themeMode == ThemeMode.dark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showHelpAndSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.helpCircle, color: Colors.indigo),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Помощь и поддержка',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Нужна помощь? Мы здесь для вас!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.mail, color: Colors.indigo),
              title: const Text('Email поддержка'),
              subtitle: const Text('support@aistudymate.ru'),
              onTap: () async {
                final uri = Uri.parse(
                    'mailto:support@aistudymate.ru?subject=Помощь с AI-StudyMate');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(LucideIcons.messageCircle, color: Colors.green),
              title: const Text('Telegram поддержка'),
              subtitle: const Text('@aistudymate_support'),
              onTap: () async {
                final uri = Uri.parse('https://t.me/aistudymate_support');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Часто задаваемые вопросы',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Как работает AI-анализ?\n• Как создать учебный набор?\n• Как использовать диктофон?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showTelegramIntegration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.send, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Telegram интеграция',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Подключите Telegram бот для получения уведомлений и быстрого доступа к материалам!',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF0088CC).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Как подключить:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Найдите @AIStudyMate_Bot в Telegram\n'
                    '2. Нажмите "Start"\n'
                    '3. Введите код: ${_user?.uid ?? "..."}\n'
                    '4. Готово! ✨',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final uri = Uri.parse('https://t.me/AIStudyMate_Bot');
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Не удалось открыть Telegram: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(LucideIcons.send, size: 18),
                      label: const Text('Открыть Telegram бот'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0088CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      String title, Widget trailing, Color? borderColor, Color textColor,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: borderColor != null
            ? BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: borderColor, width: 1)))
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
            trailing,
          ],
        ),
      ),
    );
  }
}
