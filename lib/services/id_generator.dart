import 'package:shared_preferences/shared_preferences.dart';

// Generate and store auto-incrementing IDs for weight entries.
// Role: provide a unique `id` per profile (or globally) and persist it.
class IdGenerator {
  static const _keyPrefix = 'last_weight_entry_id';

  /// Return the SharedPreferences key for a given profile
  /// (or the global key if `profileId` is null).
  static String _key([String? profileId]) =>
      profileId != null ? '${_keyPrefix}_$profileId' : _keyPrefix;

  /// Return the next auto-incremented id and persist it.
  static Future<int> getNextId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_key(profileId)) ?? 0;
    final next = last + 1;
    await prefs.setInt(_key(profileId), next);
    return next;
  }

  /// Read the last id without incrementing (useful for inspection).
  static Future<int> getLastId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(profileId)) ?? 0;
  }

  /// Reset the counter (mainly useful for tests).
  static Future<void> reset([int value = 0, String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(profileId), value);
  }
}
