import 'package:flutter/material.dart';
import '../models/notebook_entry.dart';
import '../services/api_service.dart';

class NotebookProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<NotebookEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  List<NotebookEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cache duration: 2 minutes
  bool get _shouldRefresh {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > const Duration(minutes: 2);
  }

  Future<void> loadEntries(
    int userId, {
    String? type,
    List<String>? tags,
    String? course,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !_shouldRefresh && _entries.isNotEmpty) {
      print('[NOTEBOOK_PROVIDER] Using cached entries (${_entries.length} items)');
      return;
    }

    print('[NOTEBOOK_PROVIDER] Loading entries for userId=$userId, type=$type, forceRefresh=$forceRefresh');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getNotebookEntries(
        userId,
        type: type,
        tags: tags,
        course: course,
        search: search,
      );

      print('[NOTEBOOK_PROVIDER] API result: ${result['success']}, message: ${result['message']}');

      if (result['success'] == true) {
        final data = result['data'];
        _entries = (data['data'] as List)
            .map((e) => NotebookEntry.fromJson(e))
            .toList();
        _lastUpdate = DateTime.now();
        _error = null;
        print('[NOTEBOOK_PROVIDER] Loaded ${_entries.length} entries');
      } else {
        _error = result['message'] ?? 'Ошибка загрузки записей';
        print('[NOTEBOOK_PROVIDER] Error: $_error');
      }
    } catch (e) {
      _error = 'Ошибка подключения: $e';
      print('[NOTEBOOK_PROVIDER] Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createEntry({
    required int userId,
    required String type,
    required String title,
    String? summary,
    List<String>? tags,
    String? course,
    String? linkedResourceId,
    String? manualNotes,
  }) async {
    try {
      final result = await _apiService.createNotebookEntry(
        userId: userId,
        type: type,
        title: title,
        summary: summary,
        tags: tags,
        course: course,
        linkedResourceId: linkedResourceId,
        manualNotes: manualNotes,
      );

      if (result['success'] == true) {
        await loadEntries(userId, forceRefresh: true);
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка создания записи: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEntry({
    required int userId,
    required String entryId,
    String? title,
    String? summary,
    List<String>? tags,
    String? course,
    String? manualNotes,
  }) async {
    try {
      final result = await _apiService.updateNotebookEntry(
        userId: userId,
        entryId: entryId,
        title: title,
        summary: summary,
        tags: tags,
        course: course,
        manualNotes: manualNotes,
      );

      if (result['success'] == true) {
        await loadEntries(userId, forceRefresh: true);
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка обновления записи: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEntry(int userId, String entryId) async {
    try {
      final result = await _apiService.deleteNotebookEntry(userId, entryId);

      if (result['success'] == true) {
        _entries.removeWhere((e) => e.id == entryId);
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Ошибка удаления записи: $e';
      notifyListeners();
      return false;
    }
  }

  List<NotebookEntry> filterByType(EntryType type) {
    return _entries.where((e) => e.type == type).toList();
  }

  List<NotebookEntry> filterByCourse(String course) {
    return _entries.where((e) => e.course == course).toList();
  }

  void clearCache() {
    _entries = [];
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }
}

