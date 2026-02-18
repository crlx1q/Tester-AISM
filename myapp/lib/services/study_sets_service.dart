import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../models/study_set.dart';

class StudySetsService {
  static final StudySetsService _instance = StudySetsService._internal();
  factory StudySetsService() => _instance;
  StudySetsService._internal();

  static const String _storageKey = 'study_sets';
  final List<StudySet> _studySets = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final String? setsData = prefs.getString(_storageKey);
    
    if (setsData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(setsData);
        _studySets.clear();
        _studySets.addAll(jsonList.map((json) => StudySet.fromJson(json)).toList());
      } catch (e) {
        print('Error loading study sets: $e');
        // Load demo data if there's an error
        _loadDemoData();
      }
    } else {
      // Load demo data for first time users
      _loadDemoData();
    }
    
    _initialized = true;
  }

  void _loadDemoData() {
    _studySets.addAll([
      StudySet(
        id: '1',
        title: 'Основы биологии',
        cards: [
          StudyCard(
            term: 'Митохондрия',
            definition: 'Органелла, отвечающая за клеточное дыхание и производство АТФ.',
          ),
          StudyCard(
            term: 'Фотосинтез',
            definition: 'Процесс, при котором растения преобразуют свет в химическую энергию.',
          ),
          StudyCard(
            term: 'ДНК',
            definition: 'Дезоксирибонуклеиновая кислота - молекула, содержащая генетическую информацию.',
          ),
        ],
        icon: LucideIcons.dna,
        color: Colors.green,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        progress: 0.45,
      ),
      StudySet(
        id: '2',
        title: 'История Древнего Рима',
        cards: [
          StudyCard(
            term: 'Юлий Цезарь',
            definition: 'Римский полководец и диктатор, завоевавший Галлию.',
          ),
          StudyCard(
            term: 'Колизей',
            definition: 'Амфитеатр в Риме, памятник архитектуры, вмещавший до 80 000 зрителей.',
          ),
          StudyCard(
            term: 'Пунические войны',
            definition: 'Серия из трёх войн между Римом и Карфагеном (264-146 гг. до н.э.).',
          ),
        ],
        icon: LucideIcons.landmark,
        color: Colors.amber,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      StudySet(
        id: '3',
        title: 'Физика 101',
        cards: [
          StudyCard(
            term: 'Первый закон Ньютона',
            definition: 'Тело остается в покое или движется равномерно, пока на него не действует внешняя сила.',
          ),
          StudyCard(
            term: 'E = mc²',
            definition: 'Формула эквивалентности массы и энергии Эйнштейна.',
          ),
        ],
        icon: LucideIcons.atom,
        color: Colors.blue,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        progress: 0.75,
      ),
    ]);
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _studySets.map((set) => set.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<List<StudySet>> getStudySets() async {
    await initialize();
    return List.unmodifiable(_studySets);
  }

  Future<StudySet?> getStudySet(String id) async {
    await initialize();
    try {
      return _studySets.firstWhere((set) => set.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveStudySet(StudySet studySet) async {
    await initialize();
    
    // Check if set with same ID exists
    final existingIndex = _studySets.indexWhere((set) => set.id == studySet.id);
    
    if (existingIndex >= 0) {
      _studySets[existingIndex] = studySet;
    } else {
      _studySets.add(studySet);
    }
    
    await _saveToStorage();
  }

  Future<void> deleteStudySet(String id) async {
    await initialize();
    _studySets.removeWhere((set) => set.id == id);
    await _saveToStorage();
  }

  Future<void> updateProgress(String setId, double progress) async {
    await initialize();
    
    final index = _studySets.indexWhere((set) => set.id == setId);
    if (index >= 0) {
      final oldSet = _studySets[index];
      _studySets[index] = StudySet(
        id: oldSet.id,
        title: oldSet.title,
        cards: oldSet.cards,
        icon: oldSet.icon,
        color: oldSet.color,
        createdAt: oldSet.createdAt,
        progress: progress.clamp(0.0, 1.0),
      );
      await _saveToStorage();
    }
  }

  StudySet? getCurrentLearningSet() {
    if (_studySets.isEmpty) return null;
    
    // Return the set with the most recent activity or highest progress
    final sortedSets = List<StudySet>.from(_studySets)
      ..sort((a, b) {
        // First priority: sets with progress but not completed
        if (a.progress > 0 && a.progress < 1.0) {
          if (b.progress == 0 || b.progress == 1.0) return -1;
        } else if (b.progress > 0 && b.progress < 1.0) {
          return 1;
        }
        
        // Second priority: most recently created
        return b.createdAt.compareTo(a.createdAt);
      });
    
    return sortedSets.first;
  }
}
