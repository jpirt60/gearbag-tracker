import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration from v1.0 SharedPreferences storage to sqflite.
/// Per discard policy: we drop the old blob entirely. Existing testers
/// will start with an empty gear bag on v1.1 upgrade.
class LegacyMigration {
  static const _oldStorageKey = 'gear_list_v1';
  static const _migrationDoneKey = 'sqflite_migration_done_v1';

  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationDoneKey) == true) return;

    // Discard the old blob — per locked-in policy (option B).
    await prefs.remove(_oldStorageKey);
    await prefs.setBool(_migrationDoneKey, true);
  }
}