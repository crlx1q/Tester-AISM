import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../screens/focus_page.dart';
import 'focus_page_visibility.dart';

class FocusOverlayManager {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void show(BuildContext context, FocusProvider provider) {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => ChangeNotifierProvider.value(
        value: provider,
        child: _FloatingFocusOverlay(
          onClose: () => hide(),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  static bool get isShowing => _isShowing;
}

class _FloatingFocusOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const _FloatingFocusOverlay({
    required this.onClose,
  });

  @override
  State<_FloatingFocusOverlay> createState() => _FloatingFocusOverlayState();
}

class _FloatingFocusOverlayState extends State<_FloatingFocusOverlay> {
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, provider, child) {
        // Показываем только когда таймер активен
        if (provider.timerState == FocusTimerState.idle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onClose();
          });
          return const SizedBox.shrink();
        }

        // Не показываем на экране FocusPage
        if (FocusPageVisibility.isOnFocusPage) {
          return const SizedBox.shrink();
        }

        final screenSize = MediaQuery.of(context).size;
        final remainingMinutes = provider.remainingSeconds ~/ 60;
        final remainingSeconds = provider.remainingSeconds % 60;

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  (_position.dx + details.delta.dx)
                      .clamp(0, screenSize.width - 140),
                  (_position.dy + details.delta.dy)
                      .clamp(0, screenSize.height - 70),
                );
              });
            },
            onPanEnd: (details) {
              setState(() {
                _isDragging = false;
              });
            },
            onTap: () {
              if (!_isDragging) {
                // Открываем полный экран фокуса
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FocusPage(),
                  ),
                );
              }
            },
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
                      color: Colors.black.withOpacity(_isDragging ? 0.4 : 0.3),
                      blurRadius: _isDragging ? 20 : 12,
                      offset: Offset(0, _isDragging ? 8 : 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Иконка
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        provider.currentSession!.isBreak
                            ? LucideIcons.coffee
                            : LucideIcons.target,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Таймер
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.currentSession!.isBreak
                              ? 'Перерыв'
                              : 'Фокус',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Индикатор паузы
                    if (provider.timerState == FocusTimerState.paused)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.pause,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
