import 'dart:convert';

import 'ai_meta.dart';

class ProStatus {
  final bool status;
  final String? endDate;

  ProStatus({required this.status, this.endDate});

  factory ProStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProStatus(status: false);
    return ProStatus(
      status: json['status'] == true,
      endDate: json['endDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'endDate': endDate,
    };
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final List<String> badges;
  final String uid;
  final AiMeta? ai;
  final ProStatus? pro;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.badges,
    required this.uid,
    this.ai,
    this.pro,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final uidValue = json['uid'];
    final uidString = uidValue is String
        ? uidValue
        : (uidValue != null ? uidValue.toString() : '');

    List<String> badgeList = [];
    final badges = json['badges'];
    if (badges is List) {
      badgeList = badges.map((badge) => badge.toString()).toList();
    }

    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      badges: badgeList,
      uid: uidString,
      ai: AiMeta.fromJson(json['ai'] as Map<String, dynamic>?),
      pro: ProStatus.fromJson(json['pro'] as Map<String, dynamic>?),
    );
  }

  static User? fromSharedPreferences(String? jsonData) {
    if (jsonData == null) return null;
    return User.fromJson(jsonDecode(jsonData));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'badges': badges,
      'uid': uid,
      'ai': ai?.toJson(),
      'pro': pro?.toJson(),
    };
  }
}
