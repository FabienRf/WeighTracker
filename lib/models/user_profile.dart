import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String id;
  final String name;
  final int height; // height in cm (integer)
  final double weight;
  final double goalWeight;

  UserProfile({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.goalWeight,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    int? height,
    double? weight,
    double? goalWeight,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goalWeight: goalWeight ?? this.goalWeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'height': height,
    'weight': weight,
    'goalWeight': goalWeight,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id:
        json['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] as String,
    height: (json['height'] as num).toInt(),
    weight: (json['weight'] as num).toDouble(),
    goalWeight: (json['goalWeight'] as num).toDouble(),
  );

  // ── Multi-profile storage ──

  static const _profilesKey = 'user_profiles';
  static const _activeProfileKey = 'active_profile_id';

  /// Generate a unique ID for a new profile.
  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Load all saved profiles.
  static Future<List<UserProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_profilesKey);
    if (s == null) return [];
    try {
      final List<dynamic> list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a list of profiles.
  static Future<void> saveAll(List<UserProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  /// Add or update this profile in the stored list.
  Future<void> save() async {
    final profiles = await loadAll();
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      profiles[idx] = this;
    } else {
      profiles.add(this);
    }
    await saveAll(profiles);
  }

  /// Delete this profile and its associated weight entries.
  Future<void> delete() async {
    final profiles = await loadAll();
    profiles.removeWhere((p) => p.id == id);
    await saveAll(profiles);
    // Clean up weight data for this profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('weight_entries_$id');
    await prefs.remove('last_weight_entry_id_$id');
    // If this was the active profile, clear active
    final activeId = prefs.getString(_activeProfileKey);
    if (activeId == id) {
      await prefs.remove(_activeProfileKey);
    }
  }

  /// Set this profile as the active (selected) profile.
  Future<void> setActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, id);
  }

  /// Load the currently active profile, or null.
  static Future<UserProfile?> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeProfileKey);
    if (activeId == null) return null;
    final profiles = await loadAll();
    try {
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (_) {
      return null;
    }
  }

  // ── Legacy single-profile compat ──

  static const _prefsKey = 'user_profile';

  /// Migrate old single-profile data to the new list format.
  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final oldData = prefs.getString(_prefsKey);
    if (oldData != null) {
      try {
        final m = jsonDecode(oldData) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(m);
        // Save into the new list format
        await profile.save();
        await profile.setActive();
        // Migrate weight entries to profile-specific key
        final oldEntries = prefs.getString('weight_entries');
        if (oldEntries != null) {
          await prefs.setString('weight_entries_${profile.id}', oldEntries);
          await prefs.remove('weight_entries');
        }
        final oldLastId = prefs.getInt('last_weight_entry_id');
        if (oldLastId != null) {
          await prefs.setInt('last_weight_entry_id_${profile.id}', oldLastId);
          await prefs.remove('last_weight_entry_id');
        }
        // Remove old key
        await prefs.remove(_prefsKey);
      } catch (_) {
        await prefs.remove(_prefsKey);
      }
    }
  }

  /// Legacy load — now loads the active profile.
  static Future<UserProfile?> load() async {
    await migrateIfNeeded();
    return loadActive();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
  }
}
