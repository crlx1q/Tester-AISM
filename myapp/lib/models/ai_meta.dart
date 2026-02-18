class AiUsageInfo {
  final String feature;
  final int dailyCount;
  final int remaining;
  final int limit;
  final int totalCount;
  final DateTime? lastReset;

  const AiUsageInfo({
    required this.feature,
    required this.dailyCount,
    required this.remaining,
    required this.limit,
    required this.totalCount,
    this.lastReset,
  });

  factory AiUsageInfo.fromJson(String feature, Map<String, dynamic>? json) {
    if (json == null) {
      return AiUsageInfo(
        feature: feature,
        dailyCount: 0,
        remaining: 0,
        limit: 0,
        totalCount: 0,
        lastReset: null,
      );
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse('$value') ?? 0;
    }

    return AiUsageInfo(
      feature: feature,
      dailyCount: parseInt(json['dailyCount']),
      remaining: parseInt(json['remaining']),
      limit: parseInt(json['limit']),
      totalCount: parseInt(json['totalCount']),
      lastReset: json['lastReset'] != null ? DateTime.tryParse(json['lastReset']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'dailyCount': dailyCount,
        'remaining': remaining,
        'limit': limit,
        'totalCount': totalCount,
        'lastReset': lastReset?.toIso8601String(),
      };
}

class AiStreak {
  final int current;
  final int longest;
  final DateTime? lastActiveDate;
  final DateTime? updatedAt;

  const AiStreak({
    required this.current,
    required this.longest,
    this.lastActiveDate,
    this.updatedAt,
  });

  factory AiStreak.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AiStreak(current: 0, longest: 0);
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse('$value') ?? 0;
    }

    return AiStreak(
      current: parseInt(json['current']),
      longest: parseInt(json['longest']),
      lastActiveDate: json['lastActiveDate'] != null ? DateTime.tryParse(json['lastActiveDate']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'current': current,
        'longest': longest,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

class AiMeta {
  final Map<String, AiUsageInfo> usage;
  final AiStreak streak;
  final Map<String, int> historyCounts;

  const AiMeta({
    required this.usage,
    required this.streak,
    required this.historyCounts,
  });

  factory AiMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AiMeta(
        usage: const {},
        streak: const AiStreak(current: 0, longest: 0),
        historyCounts: const {},
      );
    }

    final usageJson = json['usage'] as Map<String, dynamic>?;
    final streakJson = json['streak'] as Map<String, dynamic>?;
    final historyJson = json['historyCounts'] as Map<String, dynamic>?;

    final Map<String, AiUsageInfo> usage = {};
    usageJson?.forEach((key, value) {
      usage[key] = AiUsageInfo.fromJson(key, value as Map<String, dynamic>?);
    });

    final Map<String, int> historyCounts = {};
    historyJson?.forEach((key, value) {
      if (value is int) {
        historyCounts[key] = value;
      } else {
        historyCounts[key] = int.tryParse('$value') ?? 0;
      }
    });

    return AiMeta(
      usage: usage,
      streak: AiStreak.fromJson(streakJson),
      historyCounts: historyCounts,
    );
  }

  Map<String, dynamic> toJson() => {
        'usage': usage.map((key, value) => MapEntry(key, value.toJson())),
        'streak': streak.toJson(),
        'historyCounts': historyCounts,
      };

  AiUsageInfo? usageFor(String feature) => usage[feature];
}
