import 'package:shared_preferences/shared_preferences.dart';

class IdGenerator {
  static const _keyPrefix = 'last_weight_entry_id';

  /// Returns the key for a given profile ID (or global fallback).
  static String _key([String? profileId]) =>
      profileId != null ? '${_keyPrefix}_$profileId' : _keyPrefix;

  /// Returns the next auto-increment id and persists it across app restarts.
  static Future<int> getNextId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_key(profileId)) ?? 0;
    final next = last + 1;
    await prefs.setInt(_key(profileId), next);
    return next;
  }

  /// Optional: read current last id without incrementing.
  static Future<int> getLastId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(profileId)) ?? 0;
  }

  /// Optional: reset the counter (useful for tests).
  static Future<void> reset([int value = 0, String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(profileId), value);
  }
}
