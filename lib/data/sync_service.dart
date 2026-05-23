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
  RealtimeChannel? _gearChannel;
  RealtimeChannel? _notesChannel;

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

  /// Push all locally-pending changes to Supabase.
  /// Called after local mutations and on app foreground.
  Future<bool> pushPending() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _lastError = 'Not authenticated';
      return false;
    }

    // Don't change state for push if a pull is already running
    final wasIdle = _state == SyncState.idle;
    if (wasIdle) {
      _state = SyncState.syncing;
      notifyListeners();
    }

    try {
      await _pushPendingGear();
      await _pushPendingUsageNotes();

      if (wasIdle) {
        _state = SyncState.idle;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _state = SyncState.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }
  /// Manual sync triggered by user action (refresh button / pull-to-refresh).
  /// Pushes any pending local changes then pulls remote state.
  Future<bool> syncNow() async {
    final pushOk = await pushPending();
    final pullOk = await pullAll();
    return pushOk && pullOk;
  }
  /// Subscribe to realtime changes for the current user's gear + usage notes.
  /// Call once on login.
  void startRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Avoid double-subscription
    stopRealtime();

    _gearChannel = _supabase
        .channel('public:gear:user=${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'gear',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) => _handleGearChange(payload),
    )
        .subscribe();

    _notesChannel = _supabase
        .channel('public:usage_notes:user=${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'usage_notes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) => _handleUsageNoteChange(payload),
    )
        .subscribe();
  }

  /// Tear down subscriptions. Call on logout.
  Future<void> stopRealtime() async {
    if (_gearChannel != null) {
      await _supabase.removeChannel(_gearChannel!);
      _gearChannel = null;
    }
    if (_notesChannel != null) {
      await _supabase.removeChannel(_notesChannel!);
      _notesChannel = null;
    }
  }

  Future<void> _handleGearChange(PostgresChangePayload payload) async {
    final dh = DatabaseHelper.instance;
    final newRecord = payload.newRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldId = payload.oldRecord['id'] as String?;
      if (oldId != null) {
        await dh.softDeleteGear(oldId);
        await dh.markGearClean(oldId);
      }
      notifyListeners();
      return;
    }

    if (newRecord.isEmpty) {
      notifyListeners();
      return;
    }

    await _mergeGear([newRecord]);
    notifyListeners();
  }

  Future<void> _handleUsageNoteChange(PostgresChangePayload payload) async {
    final dh = DatabaseHelper.instance;
    final newRecord = payload.newRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldId = payload.oldRecord['id'] as String?;
      if (oldId != null) {
        await dh.softDeleteUsageNote(oldId);
        await dh.markUsageNoteClean(oldId);
      }
      notifyListeners();
      return;
    }

    if (newRecord.isEmpty) {
      notifyListeners();
      return;
    }

    await _mergeUsageNotes([newRecord]);
    notifyListeners();
  }

  Future<void> _pushPendingGear() async {
    final dh = DatabaseHelper.instance;
    final pending = await dh.getPendingGear();

    for (final gear in pending) {
      try {
        if (gear.syncStatus == 'pending_delete') {
          // Soft delete on remote
          await _supabase
              .from('gear')
              .update({
            'deleted_at': gear.deletedAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'updated_at': gear.updatedAt.toIso8601String(),
          })
              .eq('id', gear.id);
        } else {
          // pending_create or pending_update — upsert
          await _supabase.from('gear').upsert({
            'id': gear.id,
            'user_id': gear.userId,
            'type': gear.type,
            'brand': gear.brand,
            'model': gear.model,
            'status': gear.status,
            'notes': gear.notes,
            'created_at': gear.createdAt.toIso8601String(),
            'updated_at': gear.updatedAt.toIso8601String(),
            'deleted_at': gear.deletedAt?.toIso8601String(),
          });
        }
        await dh.markGearClean(gear.id);
      } catch (e) {
        // Leave the row pending — next push will retry
        // Don't throw, keep processing other pending rows
        // ignore: avoid_print
        print('Failed to push gear ${gear.id}: $e');
      }
    }
  }

  Future<void> _pushPendingUsageNotes() async {
    final dh = DatabaseHelper.instance;
    final pending = await dh.getPendingUsageNotes();

    for (final note in pending) {
      try {
        if (note.syncStatus == 'pending_delete') {
          await _supabase
              .from('usage_notes')
              .update({
            'deleted_at': note.deletedAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'updated_at': note.updatedAt.toIso8601String(),
          })
              .eq('id', note.id);
        } else {
          await _supabase.from('usage_notes').upsert({
            'id': note.id,
            'gear_id': note.gearId,
            'user_id': note.userId,
            'text': note.text,
            'created_at': note.createdAt.toIso8601String(),
            'updated_at': note.updatedAt.toIso8601String(),
            'deleted_at': note.deletedAt?.toIso8601String(),
          });
        }
        await dh.markUsageNoteClean(note.id);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to push usage note ${note.id}: $e');
      }
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