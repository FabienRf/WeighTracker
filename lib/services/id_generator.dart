import 'package:shared_preferences/shared_preferences.dart';

// Génère et stocke des identifiants auto-incrémentés pour les entrées de poids.
// Rôle: fournir un `id` unique par profil (ou global) et le persister.
class IdGenerator {
  static const _keyPrefix = 'last_weight_entry_id';

  /// Retourne la clé utilisée dans SharedPreferences pour un profil donné
  /// (ou la clé globale si `profileId` est null).
  static String _key([String? profileId]) =>
      profileId != null ? '${_keyPrefix}_$profileId' : _keyPrefix;

  /// Renvoie le prochain id auto-incrémenté et le sauvegarde.
  static Future<int> getNextId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_key(profileId)) ?? 0;
    final next = last + 1;
    await prefs.setInt(_key(profileId), next);
    return next;
  }

  /// Lecture du dernier id sans l'incrémenter (utile pour l'inspection).
  static Future<int> getLastId([String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(profileId)) ?? 0;
  }

  /// Réinitialise le compteur (principalement utile pour les tests).
  static Future<void> reset([int value = 0, String? profileId]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(profileId), value);
  }
}
