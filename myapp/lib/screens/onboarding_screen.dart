import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': LucideIcons.bookOpen,
      'title': 'Добро пожаловать',
      'description': 'Превратите фото конспектов в карточки и тесты. Учитесь умнее, а не усерднее.',
    },
    {
      'icon': LucideIcons.mic,
      'title': 'Записывайте лекции',
      'description': 'Наш AI-ассистент прослушает лекцию за вас, выделив самое важное.',
    },
    {
      'icon': LucideIcons.brainCircuit,
      'title': 'Получайте AI-анализ',
      'description': 'Получите краткую сводку, ключевые моменты и готовый конспект после каждой записи.',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildOnboardingPage(
                  _pages[index]['icon'],
                  _pages[index]['title'],
                  _pages[index]['description'],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) => _buildDot(index)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        widget.onCompleted();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1 ? 'Далее' : 'Начать работу',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(IconData icon, String title, String description) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1f2937);
    final subtextColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF9ca3af) : const Color(0xFF6b7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: Colors.indigo),
          const SizedBox(height: 48),
          Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: subtextColor, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.indigo : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
