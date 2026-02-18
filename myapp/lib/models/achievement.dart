import 'package:flutter/material.dart';

enum AchievementType {
  quiz, // Квизы
  chat, // Чат с ИИ
  streak, // Серии дней
  cards, // Карточки
  studyTime, // Время учебы
  level, // Уровни
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon; // Название иконки из lucide_icons
  final AchievementType type;
  final int requiredValue; // Требуемое значение для получения
  final Color color;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.requiredValue,
    required this.color,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'type': type.toString().split('.').last,
    'requiredValue': requiredValue,
    'color': color.value,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    icon: json['icon'],
    type: AchievementType.values.firstWhere(
      (e) => e.toString().split('.').last == json['type'],
      orElse: () => AchievementType.quiz,
    ),
    requiredValue: json['requiredValue'],
    color: Color(json['color']),
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
  );

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      icon: icon,
      type: type,
      requiredValue: requiredValue,
      color: color,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

// Предопределенные достижения
class Achievements {
  static List<Achievement> get all => [
    // Квизы
    Achievement(
      id: 'quiz_first',
      name: 'Первый шаг',
      description: 'Пройди свой первый квиз',
      icon: 'sparkles',
      type: AchievementType.quiz,
      requiredValue: 1,
      color: Colors.blue,
    ),
    Achievement(
      id: 'quiz_master',
      name: 'Мастер квизов',
      description: 'Пройди 10 квизов',
      icon: 'award',
      type: AchievementType.quiz,
      requiredValue: 10,
      color: Colors.purple,
    ),
    Achievement(
      id: 'quiz_perfect',
      name: 'Идеально!',
      description: 'Получи 100% в квизе',
      icon: 'star',
      type: AchievementType.quiz,
      requiredValue: 100,
      color: Colors.amber,
    ),
    
    // Чат с ИИ
    Achievement(
      id: 'chat_first',
      name: 'Знакомство',
      description: 'Отправь первое сообщение Айдару',
      icon: 'messageCircle',
      type: AchievementType.chat,
      requiredValue: 1,
      color: Colors.green,
    ),
    Achievement(
      id: 'chat_conversation',
      name: 'Общительный',
      description: 'Проведи 5 бесед с Айдаром',
      icon: 'messagesSquare',
      type: AchievementType.chat,
      requiredValue: 5,
      color: Colors.teal,
    ),
    
    // Серии дней
    Achievement(
      id: 'streak_3',
      name: 'Набираю темп',
      description: 'Учись 3 дня подряд',
      icon: 'flame',
      type: AchievementType.streak,
      requiredValue: 3,
      color: Colors.orange,
    ),
    Achievement(
      id: 'streak_7',
      name: 'Ударный темп',
      description: 'Учись 7 дней подряд',
      icon: 'flame',
      type: AchievementType.streak,
      requiredValue: 7,
      color: Colors.red,
    ),
    
    // Карточки
    Achievement(
      id: 'cards_creator',
      name: 'Создатель',
      description: 'Создай свой первый набор карточек',
      icon: 'layers',
      type: AchievementType.cards,
      requiredValue: 1,
      color: Colors.indigo,
    ),
    Achievement(
      id: 'cards_collector',
      name: 'Коллекционер',
      description: 'Создай 5 наборов карточек',
      icon: 'archive',
      type: AchievementType.cards,
      requiredValue: 5,
      color: Colors.deepPurple,
    ),
    
    // Время учебы
    Achievement(
      id: 'study_hour',
      name: 'Час знаний',
      description: 'Проведи 1 час в учебе',
      icon: 'clock',
      type: AchievementType.studyTime,
      requiredValue: 60, // минуты
      color: Colors.cyan,
    ),
    Achievement(
      id: 'study_marathon',
      name: 'Марафон учебы',
      description: 'Проведи 10 часов в учебе',
      icon: 'timer',
      type: AchievementType.studyTime,
      requiredValue: 600, // минуты
      color: Colors.blueGrey,
    ),
    
    // Уровни
    Achievement(
      id: 'level_advanced',
      name: 'Продвинутый',
      description: 'Достигни уровня 3 в любой теме',
      icon: 'trendingUp',
      type: AchievementType.level,
      requiredValue: 3,
      color: Colors.pink,
    ),
    Achievement(
      id: 'level_master',
      name: 'Мастер',
      description: 'Достигни уровня 5 в любой теме',
      icon: 'crown',
      type: AchievementType.level,
      requiredValue: 5,
      color: Colors.amber,
    ),
  ];
}

