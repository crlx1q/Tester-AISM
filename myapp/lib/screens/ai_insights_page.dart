import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/insights_provider.dart';
import '../services/profile_notifier.dart';

class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({Key? key}) : super(key: key);

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsights();
    });
  }

  void _loadInsights() {
    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user != null) {
      Provider.of<InsightsProvider>(context, listen: false)
          .loadLatestInsight(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Insights',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<ProfileNotifier>(
            builder: (context, notifier, child) {
              final user = notifier.user;
              final isPro = user?.pro?.status == true;
              
              if (!isPro) return const SizedBox.shrink();
              
              return IconButton(
                icon: Icon(LucideIcons.refreshCw, color: textColor),
                onPressed: () => _regenerateInsights(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<ProfileNotifier>(
        builder: (context, profileNotifier, child) {
          final user = profileNotifier.user;
          final isPro = user?.pro?.status == true;
          
          // Если не PRO пользователь, показываем экран с предложением подписки
          if (!isPro) {
            return _buildPremiumPromoScreen(context, textColor, subtextColor, cardColor);
          }
          
          // Для PRO пользователей показываем обычный контент
          return Consumer<InsightsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.alertCircle, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: TextStyle(color: subtextColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInsights,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final insight = provider.latestInsight;

          if (insight == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.sparkles, color: subtextColor, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных для анализа',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Продолжайте учиться, чтобы AI мог\nсоздать персональные инсайты',
                    style: TextStyle(color: subtextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(insight, cardColor, textColor, subtextColor),
                
                const SizedBox(height: 24),
                
                // Stats Summary
                _buildStatsGrid(insight, cardColor, textColor, subtextColor),
                
                const SizedBox(height: 24),
                
                // Learned Topics
                if (insight.learnedTopics.isNotEmpty)
                  _buildSection(
                    'Что нового изучил',
                    LucideIcons.book,
                    Colors.green,
                    insight.learnedTopics,
                    cardColor,
                    textColor,
                    subtextColor,
                  ),
                
                const SizedBox(height: 20),
                
                // Weak Areas
                if (insight.weakAreas.isNotEmpty)
                  _buildSection(
                    'Что повторить',
                    LucideIcons.alertTriangle,
                    Colors.orange,
                    insight.weakAreas,
                    cardColor,
                    textColor,
                    subtextColor,
                  ),
                
                const SizedBox(height: 20),
                
                // Suggestions
                if (insight.suggestedReviews.isNotEmpty)
                  _buildSuggestions(
                    insight.suggestedReviews,
                    cardColor,
                    textColor,
                    subtextColor,
                  ),
              ],
            ),
          );
        },
      );
        },
      ),
    );
  }

  Widget _buildPremiumPromoScreen(
    BuildContext context,
    Color textColor,
    Color? subtextColor,
    Color cardColor,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // PRO Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AI Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.crown,
                        color: Colors.black,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Subtitle
            Text(
              'Эксклюзивная функция для премиум-пользователей',
              style: TextStyle(
                fontSize: 16,
                color: subtextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Features list
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
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
                  _buildFeatureItem(
                    LucideIcons.trendingUp,
                    'Анализ прогресса',
                    'Еженедельная аналитика вашего обучения',
                    textColor,
                    subtextColor,
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    LucideIcons.lightbulb,
                    'Персональные рекомендации',
                    'AI советы для улучшения результатов',
                    textColor,
                    subtextColor,
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    LucideIcons.target,
                    'Слабые места',
                    'Определение тем для повторения',
                    textColor,
                    subtextColor,
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureItem(
                    LucideIcons.bookOpen,
                    'Изученные темы',
                    'Отслеживание всего пройденного материала',
                    textColor,
                    subtextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to premium page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.crown, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Перейти на PRO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    Color textColor,
    Color? subtextColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF6366F1),
            size: 24,
          ),
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
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: subtextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    dynamic insight,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                insight.weekLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.summary,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    dynamic insight,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                LucideIcons.clock,
                '${insight.stats.totalStudyMinutes}',
                'минут учебы',
                Colors.blue,
                cardColor,
                textColor,
                subtextColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                LucideIcons.scan,
                '${insight.stats.scansCompleted}',
                'конспектов',
                Colors.green,
                cardColor,
                textColor,
                subtextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                LucideIcons.mic,
                '${insight.stats.lecturesCompleted}',
                'лекций',
                Colors.purple,
                cardColor,
                textColor,
                subtextColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                LucideIcons.trophy,
                '${insight.stats.averageScore}%',
                'средний балл',
                Colors.orange,
                cardColor,
                textColor,
                subtextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
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
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    List<String> suggestions,
    Color cardColor,
    Color textColor,
    Color? subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.lightbulb, color: Color(0xFF6366F1), size: 24),
              const SizedBox(width: 12),
              Text(
                'Рекомендации AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _regenerateInsights(BuildContext context) async {
    final profileNotifier = Provider.of<ProfileNotifier>(context, listen: false);
    final user = profileNotifier.user;
    if (user == null) return;

    final provider = Provider.of<InsightsProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Генерация инсайтов...'),
          ],
        ),
      ),
    );

    final success = await provider.generateInsight(user.id);
    
    if (context.mounted) {
      Navigator.pop(context);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Инсайты успешно обновлены!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Ошибка генерации инсайтов')),
        );
      }
    }
  }
}

