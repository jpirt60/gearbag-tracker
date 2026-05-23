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
      // Pull ALL rows (including soft-deleted) so we can reconcile tombstones
      final gearRows = await _supabase
          .from('gear')
          .select()
          .eq('user_id', user.id);

      final noteRows = await _supabase
          .from('usage_notes')
          .select()
          .eq('user_id', user.id);

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

      final local = await dh.getGearByIdIncludingDeleted(remote.id);

      if (local == null) {
        // New to this device — write it (could be a fresh row or a remotely-deleted one we never saw)
        await dh.insertGear(remote);
        continue;
      }

      if (local.syncStatus != 'clean') {
        // Local has unpushed changes. Last-write-wins by updated_at.
        // If remote is newer, local edit loses. Otherwise keep local.
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await dh.insertGear(remote);
        }
        continue;
      }

      // Local is clean — remote wins (covers create, update, and delete cases)
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

      final localRow = existing.first;
      final localStatus = localRow['sync_status'] as String? ?? 'clean';
      final localUpdatedAt = DateTime.parse(localRow['updated_at'] as String);

      if (localStatus != 'clean') {
        // Last-write-wins on conflict
        if (remote.updatedAt.isAfter(localUpdatedAt)) {
          await dh.insertUsageNote(remote);
        }
        continue;
      }

      await dh.insertUsageNote(remote);
    }
  }
}