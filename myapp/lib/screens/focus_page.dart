import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../providers/focus_provider.dart';
import '../services/focus_service.dart';
import '../services/focus_overlay_manager.dart';
import '../services/focus_page_visibility.dart';
import '../models/focus_session.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> with TickerProviderStateMixin {
  final FocusService _focusService = FocusService();
  late AnimationController _pulseController;
  bool _isOnThisScreen = false;

  @override
  void initState() {
    super.initState();
    _focusService.initialize();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Скрываем overlay при входе на экран
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isOnThisScreen = true;
      FocusPageVisibility.setOnFocusPage(true);
      FocusOverlayManager.hide();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _isOnThisScreen = false;
    FocusPageVisibility.setOnFocusPage(false);
    // Восстанавливаем overlay виджет при выходе с экрана
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isOnThisScreen) {
        final focusProvider =
            Provider.of<FocusProvider>(context, listen: false);
        if (focusProvider.timerState != FocusTimerState.idle) {
          FocusOverlayManager.show(context, focusProvider);
        }
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusProvider = Provider.of<FocusProvider>(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Режим фокусировки',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => _showSettingsDialog(context, focusProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: focusProvider.timerState == FocusTimerState.idle
            ? _buildIdleView(context, focusProvider, isDark)
            : _buildActiveTimerView(context, focusProvider, isDark),
      ),
    );
  }

  Widget _buildIdleView(
      BuildContext context, FocusProvider provider, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Статистика
          _buildStatsCards(provider, isDark),
          const SizedBox(height: 16),

          // Активный таймер (если запущен)
          if (provider.timerState != FocusTimerState.idle)
            _buildActiveTimerCard(provider, isDark),

          const SizedBox(height: 32),

          // Начать сессию
          Text(
            'Начать фокус-сессию',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Быстрый старт
          _buildQuickStartCard(
            context,
            provider,
            isDark,
            title: 'Классический Pomodoro',
            subtitle:
                '${provider.settings.focusDuration} мин фокус, ${provider.settings.shortBreakDuration} мин перерыв',
            cycles: provider.settings.cyclesBeforeLongBreak,
            icon: LucideIcons.zap,
            color: Colors.indigo,
          ),
          const SizedBox(height: 12),

          _buildQuickStartCard(
            context,
            provider,
            isDark,
            title: 'Глубокая работа',
            subtitle: '52 мин фокус, 17 мин перерыв',
            cycles: 2,
            icon: LucideIcons.brain,
            color: Colors.purple,
            customFocusDuration: 52,
            customBreakDuration: 17,
          ),
          const SizedBox(height: 12),

          _buildQuickStartCard(
            context,
            provider,
            isDark,
            title: 'Быстрая сессия',
            subtitle: '15 мин фокус, 3 мин перерыв',
            cycles: 3,
            icon: LucideIcons.timer,
            color: Colors.teal,
            customFocusDuration: 15,
            customBreakDuration: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimerCard(FocusProvider provider, bool isDark) {
    final remainingMinutes = provider.remainingSeconds ~/ 60;
    final remainingSeconds = provider.remainingSeconds % 60;

    return GestureDetector(
      onTap: () {
        // Прокрутка к экрану таймера уже на этой странице
        // Можно добавить анимацию или просто ничего не делать
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: provider.currentSession!.isBreak
                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (provider.currentSession!.isBreak
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1))
                  .withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Иконка
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                provider.currentSession!.isBreak
                    ? LucideIcons.coffee
                    : LucideIcons.target,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.currentSession!.isBreak
                        ? 'Перерыв'
                        : 'Фокус активен',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Период ${provider.currentCycle} из ${provider.totalCycles}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Индикатор состояния
            if (provider.timerState == FocusTimerState.paused)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.pause,
                  color: Colors.white,
                  size: 20,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.play,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(FocusProvider provider, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Сегодня',
            value: _formatDuration(provider.todayFocusTime),
            icon: LucideIcons.clock,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Эта неделя',
            value: _formatDuration(provider.weekFocusTime),
            icon: LucideIcons.calendar,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.white,
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartCard(
    BuildContext context,
    FocusProvider provider,
    bool isDark, {
    required String title,
    required String subtitle,
    required int cycles,
    required IconData icon,
    required Color color,
    int? customFocusDuration,
    int? customBreakDuration,
  }) {
    return InkWell(
      onTap: () {
        if (customFocusDuration != null && customBreakDuration != null) {
          provider.updateSettings(
            provider.settings.copyWith(
              focusDuration: customFocusDuration,
              shortBreakDuration: customBreakDuration,
            ),
          );
        }
        provider.startSession(cycles: cycles);
        if (provider.settings.enableWakeLock) {
          _focusService.enableWakeLock();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: isDark ? Colors.grey[400] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimerView(
      BuildContext context, FocusProvider provider, bool isDark) {
    final remainingMinutes = provider.remainingSeconds ~/ 60;
    final remainingSeconds = provider.remainingSeconds % 60;
    final totalSeconds = provider.currentSession!.isBreak
        ? (provider.currentSession!.breakDuration * 60)
        : (provider.settings.focusDuration * 60);
    final progress = provider.remainingSeconds / totalSeconds;

    return Column(
      children: [
        // Индикатор периода
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: provider.currentSession!.isBreak
                      ? Colors.green.withOpacity(0.1)
                      : Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: provider.currentSession!.isBreak
                        ? Colors.green.withOpacity(0.3)
                        : Colors.indigo.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      provider.currentSession!.isBreak
                          ? LucideIcons.coffee
                          : LucideIcons.target,
                      size: 16,
                      color: provider.currentSession!.isBreak
                          ? Colors.green
                          : Colors.indigo,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.currentSession!.isBreak ? 'Перерыв' : 'Фокус',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: provider.currentSession!.isBreak
                            ? Colors.green
                            : Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Период ${provider.currentCycle} из ${provider.totalCycles}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Круговой таймер
        _buildCircularTimer(
          progress: progress,
          minutes: remainingMinutes,
          seconds: remainingSeconds,
          isDark: isDark,
          isBreak: provider.currentSession!.isBreak,
          isPaused: provider.timerState == FocusTimerState.paused,
        ),

        const Spacer(),

        // Кнопки управления
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Стоп
                  _buildControlButton(
                    icon: LucideIcons.square,
                    color: Colors.red,
                    onPressed: () {
                      provider
                          .stopSession(); // stopSession теперь сам удаляет уведомление
                      _focusService.disableWakeLock();
                    },
                  ),
                  const SizedBox(width: 32),

                  // Пауза/Возобновить
                  _buildControlButton(
                    icon: provider.timerState == FocusTimerState.paused
                        ? LucideIcons.playCircle
                        : LucideIcons.pauseCircle,
                    color: Colors.indigo,
                    size: 72,
                    iconSize: 36,
                    onPressed: () {
                      if (provider.timerState == FocusTimerState.paused) {
                        provider.resumeTimer();
                      } else {
                        provider.pauseTimer();
                      }
                    },
                  ),
                  const SizedBox(width: 32),

                  // Пропустить
                  _buildControlButton(
                    icon: LucideIcons.fastForward,
                    color: Colors.orange,
                    onPressed: () {
                      provider.skipToNextPhase();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Информация о следующей фазе
              if (provider.currentSession != null)
                Text(
                  provider.currentSession!.isBreak
                      ? 'Далее: Фокус ${provider.settings.focusDuration} мин'
                      : 'Далее: Перерыв ${provider.settings.shortBreakDuration} мин',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularTimer({
    required double progress,
    required int minutes,
    required int seconds,
    required bool isDark,
    required bool isBreak,
    required bool isPaused,
  }) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: CircularTimerPainter(
        progress: progress,
        isDark: isDark,
        isBreak: isBreak,
        isPaused: isPaused,
      ),
      child: SizedBox(
        width: 280,
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              if (isPaused)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Пауза',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 56,
    double iconSize = 24,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    }
    return '${minutes}м';
  }

  void _showSettingsDialog(BuildContext context, FocusProvider provider) {
    showDialog(
      context: context,
      builder: (context) => _FocusSettingsDialog(provider: provider),
    );
  }
}

class CircularTimerPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isBreak;
  final bool isPaused;

  CircularTimerPainter({
    required this.progress,
    required this.isDark,
    required this.isBreak,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Фоновый круг
    final bgPaint = Paint()
      ..color =
          isDark ? const Color(0xFF374151).withOpacity(0.5) : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawCircle(center, radius, bgPaint);

    // Рисуем деления (24 штуки)
    for (int i = 0; i < 24; i++) {
      final angle = (i * 15 - 90) * pi / 180;
      final startX = center.dx + (radius - 20) * cos(angle);
      final startY = center.dy + (radius - 20) * sin(angle);
      final endX = center.dx + (radius - 8) * cos(angle);
      final endY = center.dy + (radius - 8) * sin(angle);

      final divisionPaint = Paint()
        ..color = isDark ? Colors.grey[700]! : Colors.grey[400]!
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        divisionPaint,
      );
    }

    // Прогресс
    final progressPaint = Paint()
      ..color = isPaused
          ? Colors.orange
          : isBreak
              ? Colors.green
              : Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      progressRect,
      -pi / 2,
      2 * pi * (1 - progress),
      false,
      progressPaint,
    );

    // Индикатор на конце прогресса
    final indicatorAngle = -pi / 2 + 2 * pi * (1 - progress);
    final indicatorX = center.dx + radius * cos(indicatorAngle);
    final indicatorY = center.dy + radius * sin(indicatorAngle);

    final indicatorPaint = Paint()
      ..color = isPaused
          ? Colors.orange
          : isBreak
              ? Colors.green
              : Colors.indigo
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(indicatorX, indicatorY), 6, indicatorPaint);
  }

  @override
  bool shouldRepaint(CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.isBreak != isBreak;
  }
}

class _FocusSettingsDialog extends StatefulWidget {
  final FocusProvider provider;

  const _FocusSettingsDialog({required this.provider});

  @override
  State<_FocusSettingsDialog> createState() => _FocusSettingsDialogState();
}

class _FocusSettingsDialogState extends State<_FocusSettingsDialog> {
  late FocusSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.provider.settings;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF374151) : Colors.white,
      title: const Text('Настройки фокуса'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSliderSetting(
              'Длительность фокуса',
              _settings.focusDuration.toDouble(),
              5,
              90,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    focusDuration: value.round(),
                  );
                });
              },
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              'Короткий перерыв',
              _settings.shortBreakDuration.toDouble(),
              1,
              15,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    shortBreakDuration: value.round(),
                  );
                });
              },
              isDark,
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              'Длинный перерыв',
              _settings.longBreakDuration.toDouble(),
              10,
              30,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    longBreakDuration: value.round(),
                  );
                });
              },
              isDark,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Уведомления'),
              subtitle: const Text('Показывать уведомления таймера'),
              value: _settings.enableNotifications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(enableNotifications: value);
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Не выключать экран'),
              subtitle: const Text('Держать экран активным во время фокуса'),
              value: _settings.enableWakeLock,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(enableWakeLock: value);
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.provider.updateSettings(_settings);
            Navigator.pop(context);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _buildSliderSetting(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${value.round()} мин',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
