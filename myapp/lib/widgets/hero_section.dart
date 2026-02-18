import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/planner_provider.dart';
import '../services/user_prefs.dart';
import '../models/ai_meta.dart';

class HeroSection extends StatefulWidget {
  final VoidCallback? onScanTap;
  final VoidCallback? onRecordTap;
  final VoidCallback? onChatTap;

  const HeroSection({
    Key? key,
    this.onScanTap,
    this.onRecordTap,
    this.onChatTap,
  }) : super(key: key);

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

// Global key для доступа к состоянию HeroSection
final GlobalKey<_HeroSectionState> heroSectionKey =
    GlobalKey<_HeroSectionState>();

class _HeroSectionState extends State<HeroSection> {
  int _streak = 0;
  bool _aiActiveToday = false;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  // Публичный метод для перезагрузки streak извне
  Future<void> reloadStreak() async {
    print('[HeroSection] 🔥 reloadStreak called from outside');
    await _loadStreak();
  }

  Future<void> _loadStreak() async {
    print('[HeroSection] 📊 _loadStreak started');
    final aiMetaMap = await UserPrefs.getAiMeta();
    print('[HeroSection] aiMetaMap = ${aiMetaMap?.toString()}');

    if (!mounted) {
      print('[HeroSection] ⚠️ Widget not mounted, skipping update');
      return;
    }

    final aiMeta = AiMeta.fromJson(aiMetaMap);
    final streak = aiMeta.streak;

    print(
        '[HeroSection] Parsed streak: current=${streak.current}, longest=${streak.longest}, lastActiveDate=${streak.lastActiveDate}');

    // Проверяем активен ли стрик сегодня
    bool activeToday = false;
    if (streak.lastActiveDate != null) {
      final last = streak.lastActiveDate!;
      final now = DateTime.now();
      if (last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        activeToday = true;
        print('[HeroSection] ✅ Streak is ACTIVE today!');
      } else {
        print('[HeroSection] ⚪ Streak was last active on ${last.toString()}');
      }
    } else {
      print('[HeroSection] ⚪ No lastActiveDate found');
    }

    print(
        '[HeroSection] 🎨 Setting state: streak=${streak.current}, activeToday=$activeToday');

    setState(() {
      _streak = streak.current;
      _aiActiveToday = activeToday;
    });

    print('[HeroSection] ✅ State updated successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Серия дней',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.flame,
                        color: _aiActiveToday ? Colors.orange : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_streak ${_getDayWord(_streak)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Consumer<PlannerProvider>(
                builder: (context, provider, child) {
                  final tasks = provider.getTodayTasks();
                  final completed = tasks.where((t) => t.completed).length;
                  final total = tasks.length;

                  if (total == 0) return const SizedBox.shrink();

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$completed/$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Buttons
          const Text(
            'Продолжить обучение',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: LucideIcons.scan,
                  label: 'Конспект',
                  color: Colors.green,
                  onTap: widget.onScanTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: LucideIcons.mic,
                  label: 'Лекция',
                  color: Colors.blue,
                  onTap: widget.onRecordTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: LucideIcons.messageSquare,
                  label: 'Репетитор',
                  color: Colors.purple,
                  onTap: widget.onChatTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return 'день';
    } else if ([2, 3, 4].contains(days % 10) &&
        ![12, 13, 14].contains(days % 100)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }
}
