class FocusSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int focusDuration; // в минутах
  final int breakDuration; // в минутах
  final int totalCycles;
  final int completedCycles;
  final bool isBreak;
  final bool isCompleted;
  final int totalFocusTime; // общее время фокусировки в секундах

  FocusSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.focusDuration,
    required this.breakDuration,
    required this.totalCycles,
    this.completedCycles = 0,
    this.isBreak = false,
    this.isCompleted = false,
    this.totalFocusTime = 0,
  });

  FocusSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? focusDuration,
    int? breakDuration,
    int? totalCycles,
    int? completedCycles,
    bool? isBreak,
    bool? isCompleted,
    int? totalFocusTime,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      focusDuration: focusDuration ?? this.focusDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      totalCycles: totalCycles ?? this.totalCycles,
      completedCycles: completedCycles ?? this.completedCycles,
      isBreak: isBreak ?? this.isBreak,
      isCompleted: isCompleted ?? this.isCompleted,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'focusDuration': focusDuration,
      'breakDuration': breakDuration,
      'totalCycles': totalCycles,
      'completedCycles': completedCycles,
      'isBreak': isBreak,
      'isCompleted': isCompleted,
      'totalFocusTime': totalFocusTime,
    };
  }

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      focusDuration: json['focusDuration'] as int,
      breakDuration: json['breakDuration'] as int,
      totalCycles: json['totalCycles'] as int,
      completedCycles: json['completedCycles'] as int? ?? 0,
      isBreak: json['isBreak'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      totalFocusTime: json['totalFocusTime'] as int? ?? 0,
    );
  }
}

class FocusSettings {
  final int focusDuration; // минуты
  final int shortBreakDuration; // минуты
  final int longBreakDuration; // минуты
  final int cyclesBeforeLongBreak;
  final bool enableNotifications;
  final bool enableOverlay;
  final bool enableWakeLock;

  const FocusSettings({
    this.focusDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.cyclesBeforeLongBreak = 4,
    this.enableNotifications = true,
    this.enableOverlay = true,
    this.enableWakeLock = true,
  });

  FocusSettings copyWith({
    int? focusDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? cyclesBeforeLongBreak,
    bool? enableNotifications,
    bool? enableOverlay,
    bool? enableWakeLock,
  }) {
    return FocusSettings(
      focusDuration: focusDuration ?? this.focusDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      cyclesBeforeLongBreak:
          cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableOverlay: enableOverlay ?? this.enableOverlay,
      enableWakeLock: enableWakeLock ?? this.enableWakeLock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'focusDuration': focusDuration,
      'shortBreakDuration': shortBreakDuration,
      'longBreakDuration': longBreakDuration,
      'cyclesBeforeLongBreak': cyclesBeforeLongBreak,
      'enableNotifications': enableNotifications,
      'enableOverlay': enableOverlay,
      'enableWakeLock': enableWakeLock,
    };
  }

  factory FocusSettings.fromJson(Map<String, dynamic> json) {
    return FocusSettings(
      focusDuration: json['focusDuration'] as int? ?? 25,
      shortBreakDuration: json['shortBreakDuration'] as int? ?? 5,
      longBreakDuration: json['longBreakDuration'] as int? ?? 15,
      cyclesBeforeLongBreak: json['cyclesBeforeLongBreak'] as int? ?? 4,
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      enableOverlay: json['enableOverlay'] as bool? ?? true,
      enableWakeLock: json['enableWakeLock'] as bool? ?? true,
    );
  }
}
