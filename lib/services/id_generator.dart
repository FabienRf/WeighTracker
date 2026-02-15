import 'package:shared_preferences/shared_preferences.dart';

class IdGenerator {
  static const _key = 'last_weight_entry_id';

  /// Returns the next auto-increment id and persists it across app restarts.
  static Future<int> getNextId() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_key) ?? 0;
    final next = last + 1;
    await prefs.setInt(_key, next);
    return next;
  }

  /// Optional: read current last id without incrementing.
  static Future<int> getLastId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  /// Optional: reset the counter (useful for tests).
  static Future<void> reset([int value = 0]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
  }
}
