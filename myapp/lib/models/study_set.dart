import 'package:flutter/material.dart';
import '../utils/icon_utils.dart';

class StudyCard {
  final String term;
  final String definition;
  
  StudyCard({
    required this.term,
    required this.definition,
  });
  
  Map<String, dynamic> toJson() => {
    'term': term,
    'definition': definition,
  };
  
  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
    term: json['term'],
    definition: json['definition'],
  );
}

class StudySet {
  final String id;
  final String title;
  final List<StudyCard> cards;
  final IconData icon;
  final Color color;
  final DateTime createdAt;
  final double progress;
  final List<String> tags;
  final String? course;
  
  StudySet({
    required this.id,
    required this.title,
    required this.cards,
    required this.icon,
    required this.color,
    required this.createdAt,
    this.progress = 0.0,
    this.tags = const [],
    this.course,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cards': cards.map((c) => c.toJson()).toList(),
    'icon': icon.codePoint,
    'color': color.value,
    'createdAt': createdAt.toIso8601String(),
    'progress': progress,
    'tags': tags,
    'course': course,
  };
  
  factory StudySet.fromJson(Map<String, dynamic> json) {
    return StudySet(
      id: json['id'],
      title: json['title'],
      cards: (json['cards'] as List).map((c) => StudyCard.fromJson(c)).toList(),
      icon: resolveLucideIcon(json['icon']),
      color: Color(json['color']),
      createdAt: DateTime.parse(json['createdAt']),
      progress: json['progress'] ?? 0.0,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      course: json['course'],
    );
  }
}
