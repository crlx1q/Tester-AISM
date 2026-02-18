import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';

// Ограниченный список поддерживаемых иконок Lucide, используемых в приложении
const List<IconData> allowedLucideIcons = [
  // Используются в пикере иконок
  LucideIcons.fileText,
  LucideIcons.book,
  LucideIcons.brain,
  LucideIcons.lightbulb,
  LucideIcons.star,
  LucideIcons.heart,
  LucideIcons.zap,
  LucideIcons.target,
  LucideIcons.award,
  LucideIcons.briefcase,
  LucideIcons.coffee,
  LucideIcons.code,
  LucideIcons.compass,
  LucideIcons.flame,
  LucideIcons.globe,
  LucideIcons.music,
  LucideIcons.palette,
  LucideIcons.shield,

  // Используются в демо-данных и других экранах
  LucideIcons.dna,
  LucideIcons.landmark,
  LucideIcons.atom,

  // Прочие используемые иконки в UI
  LucideIcons.pin,
  LucideIcons.pinOff,
  LucideIcons.save,
  LucideIcons.edit,
  LucideIcons.eye,
  LucideIcons.check,
  LucideIcons.checkCircle,
  LucideIcons.checkCircle2,
  LucideIcons.checkSquare,
  LucideIcons.plus,
  LucideIcons.tag,
  LucideIcons.x,
  LucideIcons.bell,
  LucideIcons.bookOpen,
  LucideIcons.circle,
  LucideIcons.minus,
  LucideIcons.trash2,
  LucideIcons.alertCircle,
  LucideIcons.arrowLeft,
];

IconData resolveLucideIcon(int? codePoint) {
  if (codePoint == null) return LucideIcons.fileText;
  for (final icon in allowedLucideIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return LucideIcons.fileText;
}


