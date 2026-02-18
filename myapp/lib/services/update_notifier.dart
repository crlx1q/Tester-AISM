import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_info.dart';
import 'update_service.dart';

class UpdateNotifier extends ChangeNotifier {
  static final UpdateNotifier _instance = UpdateNotifier._internal();
  factory UpdateNotifier() => _instance;
  UpdateNotifier._internal();

  static const _snoozeStorageKey = 'update_snooze_state';

  UpdateStatus? _status;
  UpdateStatus? get status => _status;
  DateTime? _snoozedUntil;
  String? _snoozedVersion;
  DateTime? get snoozedUntil => _snoozedUntil;
  Timer? _snoozeTimer;

  UpdateInfo? get availableUpdate => _status?.availableUpdate;

  void updateStatus(UpdateStatus status) {
    final previousVersion = _status?.availableUpdate?.version;
    _status = status;

    final currentVersion = status.availableUpdate?.version;
    if (currentVersion != null && currentVersion != previousVersion) {
      if (_snoozedVersion != null && _snoozedVersion != currentVersion) {
        _scheduleClearSnooze();
      }
    }

    notifyListeners();
  }

  void clear() {
    _status = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snoozeStorageKey);
    if (raw == null) {
      return;
    }

    try {
      final data = jsonDecode(raw);
      final version = data['version']?.toString();
      final untilString = data['until']?.toString();
      final until = untilString != null ? DateTime.tryParse(untilString) : null;

      _snoozedVersion = version;
      _snoozedUntil = until;

      if (!isSnoozed(version ?? '')) {
        _snoozedVersion = null;
        _snoozedUntil = null;
      }
    } catch (e) {
      _snoozedVersion = null;
      _snoozedUntil = null;
      await _persistSnooze();
    }

    final version = _snoozedVersion;
    final until = _snoozedUntil;
    if (version != null && until != null) {
      final remaining = until.difference(DateTime.now());
      if (remaining.isNegative) {
        _scheduleClearSnooze();
      } else {
        _startSnoozeTimer(remaining);
      }
    }

    notifyListeners();
  }

  bool isSnoozed(String version) {
    if (_snoozedVersion != version) {
      return false;
    }
    final until = _snoozedUntil;
    if (until == null) {
      return false;
    }
    if (until.isAfter(DateTime.now())) {
      return true;
    }
    _scheduleClearSnooze();
    return false;
  }

  Future<void> snooze(String version, Duration duration) async {
    _snoozedVersion = version;
    _snoozedUntil = DateTime.now().add(duration);
    _startSnoozeTimer(duration);
    await _persistSnooze();
    notifyListeners();
  }

  Future<void> clearSnooze() async {
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    _snoozedVersion = null;
    _snoozedUntil = null;
    await _persistSnooze();
    notifyListeners();
  }

  void _scheduleClearSnooze() {
    _snoozeTimer?.cancel();
    Future.microtask(() async {
      await clearSnooze();
    });
  }

  Future<void> _persistSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    if (_snoozedVersion == null || _snoozedUntil == null) {
      await prefs.remove(_snoozeStorageKey);
      return;
    }

    final payload = jsonEncode({
      'version': _snoozedVersion,
      'until': _snoozedUntil!.toIso8601String(),
    });
    await prefs.setString(_snoozeStorageKey, payload);
  }

  void _startSnoozeTimer(Duration duration) {
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer(duration, () async {
      await clearSnooze();
    });
  }
}
