import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/user_model.dart';
import '../widgets/premium_modal.dart';

class PremiumManagementPage extends StatelessWidget {
  const PremiumManagementPage({super.key, this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasPro = user?.pro?.status == true;
    final String? endDate = user?.pro?.endDate;

    ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium подписка'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatusCard(context, hasPro, endDate),
                const SizedBox(height: 24),
                _buildBenefitsSection(colors),
                const SizedBox(height: 24),
                _buildActionsSection(context, hasPro),
                const SizedBox(height: 24),
                _buildFaqSection(colors),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool hasPro, String? endDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = hasPro
        ? [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ]
        : [
            const Color(0xFF1F2937),
            const Color(0xFF111827),
          ];

    final subtitle = hasPro
        ? (endDate != null ? 'Доступ активен до $endDate' : 'Подписка активна')
        : 'Вы на бесплатном тарифе';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasPro ? LucideIcons.crown : LucideIcons.sparkles,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPro ? 'Premium активен' : 'Познакомьтесь с Premium',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            hasPro
                ? 'Спасибо, что поддерживаете развитие AIStudyMate. Мы постоянно добавляем новые фишки для продуктивной учёбы.'
                : 'Перейдите на Premium: 100 фото в день, 20 записей по 2 часа, экспорт в PDF, Telegram бот, AI Insights и приоритет к ИИ для максимальной продуктивности!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          if (!hasPro)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                PremiumModal.show(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4338CA),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(LucideIcons.crown),
              label: const Text(
                'Разблокировать Premium',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.badgeCheck,
                      color: Colors.white.withOpacity(0.9), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Все Premium возможности доступны. Делитесь обратной связью — нам важно ваше мнение!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasPro && isDark) const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(ColorScheme colors) {
    final benefits = [
      (
        LucideIcons.image,
        '100 фото в день',
        'Добавляйте до 100 фотографий ежедневно для всех ваших материалов.'
      ),
      (
        LucideIcons.mic,
        '20 записей по 2 часа ИИ',
        'ИИ диктофон с расширенными возможностями и транскрибацией.'
      ),
      (
        LucideIcons.fileDown,
        'Экспорт в PDF',
        'Сохраняйте материалы для печати и удобного обмена.'
      ),
      (
        LucideIcons.messageSquare,
        'Telegram бот',
        'Интеграция с мессенджером для быстрого доступа к материалам.'
      ),
      (
        LucideIcons.lightbulb,
        'AI Insights',
        'Умные рекомендации и детальный анализ вашего прогресса.'
      ),
      (
        LucideIcons.zap,
        'Приоритет к ИИ',
        'Молниеносные ответы и приоритетная обработка запросов.'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Что входит в Premium',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onBackground.withOpacity(0.85))),
        const SizedBox(height: 16),
        ...benefits
            .map((item) => _buildBenefitTile(item.$1, item.$2, item.$3))
            .toList(),
      ],
    );
  }

  Widget _buildBenefitTile(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        color: Colors.white.withOpacity(0.02),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, bool hasPro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Управление',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onBackground
                    .withOpacity(0.85))),
        const SizedBox(height: 16),
        _buildActionTile(
          context,
          icon: LucideIcons.creditCard,
          title: 'Изменить способ оплаты',
          description: 'Обновите карту или переключитесь на другой план.',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Мы готовим интеграцию с платежной системой.')),
            );
          },
        ),
        _buildActionTile(
          context,
          icon: LucideIcons.calendarCheck,
          title: hasPro ? 'Продлить подписку' : 'Подключить подписку',
          description: 'Выберите оптимальный тариф и активируйте Premium.',
          onTap: () {
            if (hasPro) {
              _showProRenewSheet(context);
            } else {
              Navigator.of(context).pop();
              PremiumModal.show(context);
            }
          },
        ),
        if (hasPro)
          _buildActionTile(
            context,
            icon: LucideIcons.pauseCircle,
            title: 'Поставить на паузу',
            description: 'Приостановите биллинг и возобновите в любой момент.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Пауза подписки появится в ближайшем обновлении.')),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6366F1)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: Icon(LucideIcons.chevronRight,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.6)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqSection(ColorScheme colors) {
    final faqs = [
      (
        'Что входит в Premium?',
        'Вы получаете безлимитную работу с конспектами, экспорт материалов, интеллектуальный диктофон и приоритетную поддержку.'
      ),
      (
        'Можно ли отменить подписку?',
        'Да, вы можете отменить подписку в любой момент. Доступ к Premium будет активен до конца оплаченного периода.'
      ),
      (
        'Будут ли новые функции?',
        'Мы постоянно добавляем новые инструменты: совместную работу, расширенные отчёты и интеграции с популярными платформами.'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Частые вопросы',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onBackground.withOpacity(0.85))),
        const SizedBox(height: 16),
        ...faqs.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(item.$2,
                    style:
                        TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showProRenewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.calendarClock,
                          color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Продление подписки',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Скоро появится возможность управлять биллингом прямо в приложении. Пока что напомните себе за пару дней до окончания периода — мы пришлём инструкции на почту.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Мы уведомим вас ближе к окончанию подписки.')),
                    );
                  },
                  icon: const Icon(LucideIcons.bellRing),
                  label: const Text('Получить напоминание'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
