import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gear.dart';
import '../models/usage_note.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart';


/// Tracks the current sync state for the UI to react to.
enum SyncState { idle, syncing, error }

class SyncService extends ChangeNotifier {
  SyncService._private();
  static final SyncService instance = SyncService._private();

  final _supabase = Supabase.instance.client;
  SyncState _state = SyncState.idle;
  String? _lastError;

  SyncState get state => _state;
  String? get lastError => _lastError;

  /// Pull all non-deleted gear + usage notes for the current user from
  /// Supabase and write to local DB. Used on login / fresh app open.
  ///
  /// Strategy for v1:
  /// - Pull everything (small data sets, simple)
  /// - Treat remote as source of truth: overwrite local copies
  /// - Skip rows that have local pending_* changes (they'd lose work)
  ///
  /// Returns true on success, false on error (check lastError).
  Future<bool> pullAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _lastError = 'Not authenticated';
      return false;
    }

    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final gearRows = await _supabase
          .from('gear')
          .select()
          .eq('user_id', user.id)
          .isFilter('deleted_at', null);

      final noteRows = await _supabase
          .from('usage_notes')
          .select()
          .eq('user_id', user.id)
          .isFilter('deleted_at', null);

      await _mergeGear(gearRows.cast<Map<String, dynamic>>());
      await _mergeUsageNotes(noteRows.cast<Map<String, dynamic>>());

      _state = SyncState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _state = SyncState.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _mergeGear(List<Map<String, dynamic>> remoteRows) async {
    final dh = DatabaseHelper.instance;

    for (final row in remoteRows) {
      final remote = Gear.fromMap({
        ...row,
        'sync_status': 'clean',
      });

      final local = await dh.getGearById(remote.id);

      if (local == null) {
        // New to this device — just write it
        await dh.insertGear(remote);
        continue;
      }

      if (local.syncStatus != 'clean') {
        // Local has unpushed changes — leave it alone, C.4 will resolve
        continue;
      }

      // Local is clean; trust remote
      await dh.insertGear(remote);
    }
  }

  Future<void> _mergeUsageNotes(List<Map<String, dynamic>> remoteRows) async {
    final dh = DatabaseHelper.instance;

    for (final row in remoteRows) {
      final remote = UsageNote.fromMap({
        ...row,
        'sync_status': 'clean',
      });

      // For usage notes we don't have a getById helper yet; quick query
      final db = await dh.database;
      final existing = await db.query(
        'usage_notes',
        where: 'id = ?',
        whereArgs: [remote.id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await dh.insertUsageNote(remote);
        continue;
      }

      final localStatus = existing.first['sync_status'] as String? ?? 'clean';
      if (localStatus != 'clean') continue;

      await dh.insertUsageNote(remote);
    }
  }
}