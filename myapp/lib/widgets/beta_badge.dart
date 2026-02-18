import 'package:flutter/material.dart';

enum BadgeType { beta, designer, programmer }

class BadgeIcon extends StatelessWidget {
  final BadgeType type;
  final double size;

  const BadgeIcon({super.key, required this.type, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _buildIcon(),
    );
  }

  Widget _buildIcon() {
    switch (type) {
      case BadgeType.beta:
        return Icon(Icons.science_rounded, color: const Color(0xFFfbbc04), size: size);
      case BadgeType.designer:
        return Icon(Icons.design_services_rounded, color: const Color(0xFF8b5cf6), size: size * 0.95);
      case BadgeType.programmer:
        return Icon(Icons.code_rounded, color: const Color(0xFF4285f4), size: size * 0.95);
    }
  }
}

class UserBadges extends StatelessWidget {
  final List<String> badges;
  final double iconSize;
  final double spacing;

  const UserBadges({super.key, required this.badges, this.iconSize = 20, this.spacing = 6});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalized = badges.map((badge) => badge.toLowerCase()).toSet();
    final orderedTypes = <BadgeType>[
      if (normalized.contains('beta')) BadgeType.beta,
      if (normalized.contains('designer')) BadgeType.designer,
      if (normalized.contains('programmer')) BadgeType.programmer,
    ];

    if (orderedTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: spacing,
      children: orderedTypes
          .map((type) => BadgeIcon(type: type, size: iconSize))
          .toList(growable: false),
    );
  }
}
