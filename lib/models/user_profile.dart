import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final int height; // height in cm (integer)
  final double weight;
  final double goalWeight;

  UserProfile({
    required this.name,
    required this.height,
    required this.weight,
    required this.goalWeight,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'height': height,
    'weight': weight,
    'goalWeight': goalWeight,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    height: (json['height'] as num).toInt(),
    weight: (json['weight'] as num).toDouble(),
    goalWeight: (json['goalWeight'] as num).toDouble(),
  );

  static const _prefsKey = 'user_profile';

  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsKey);
    if (s == null) return null;
    try {
      final Map<String, dynamic> m = jsonDecode(s) as Map<String, dynamic>;
      return UserProfile.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
