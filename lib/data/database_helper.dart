import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/gear.dart';
import '../models/usage_note.dart';

class DatabaseHelper {
  static const _dbName = 'gearbag.db';
  static const _dbVersion = 1;

  DatabaseHelper._private();
  static final DatabaseHelper instance = DatabaseHelper._private();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE gear (
        id           TEXT PRIMARY KEY,
        user_id      TEXT NOT NULL,
        type         TEXT NOT NULL,
        brand        TEXT NOT NULL,
        model        TEXT NOT NULL,
        status       TEXT NOT NULL DEFAULT 'active',
        notes        TEXT,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        deleted_at   TEXT,
        sync_status  TEXT NOT NULL DEFAULT 'clean'
      )
    ''');
    await db.execute('CREATE INDEX gear_user_active_idx ON gear(user_id) WHERE deleted_at IS NULL');
    await db.execute('CREATE INDEX gear_sync_idx ON gear(sync_status) WHERE sync_status != \'clean\'');

    await db.execute('''
      CREATE TABLE usage_notes (
        id           TEXT PRIMARY KEY,
        gear_id      TEXT NOT NULL REFERENCES gear(id) ON DELETE CASCADE,
        user_id      TEXT NOT NULL,
        text         TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        deleted_at   TEXT,
        sync_status  TEXT NOT NULL DEFAULT 'clean'
      )
    ''');
    await db.execute('CREATE INDEX usage_notes_gear_idx ON usage_notes(gear_id) WHERE deleted_at IS NULL');
    await db.execute('CREATE INDEX usage_notes_sync_idx ON usage_notes(sync_status) WHERE sync_status != \'clean\'');
  }

  // ============================================================
  // GEAR
  // ============================================================

  Future<List<Gear>> getGearList(String userId) async {
    final db = await database;
    final rows = await db.query(
      'gear',
      where: 'user_id = ? AND deleted_at IS NULL',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Gear.fromMap).toList();
  }

  Future<Gear?> getGearById(String id) async {
    final db = await database;
    final rows = await db.query(
      'gear',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Gear.fromMap(rows.first);
  }
  /// Same as getGearById but includes soft-deleted rows. Used by sync.
  Future<Gear?> getGearByIdIncludingDeleted(String id) async {
    final db = await database;
    final rows = await db.query(
      'gear',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Gear.fromMap(rows.first);
  }

  Future<void> insertGear(Gear gear) async {
    final db = await database;
    await db.insert('gear', gear.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGear(Gear gear) async {
    final db = await database;
    await db.update(
      'gear',
      gear.toMap(),
      where: 'id = ?',
      whereArgs: [gear.id],
    );
  }

  /// Soft delete: mark deleted_at + sync_status pending_delete.
  Future<void> softDeleteGear(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'gear',
      {
        'deleted_at': now,
        'updated_at': now,
        'sync_status': 'pending_delete',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // USAGE NOTES
  // ============================================================

  Future<List<UsageNote>> getUsageNotesByGear(String gearId) async {
    final db = await database;
    final rows = await db.query(
      'usage_notes',
      where: 'gear_id = ? AND deleted_at IS NULL',
      whereArgs: [gearId],
      orderBy: 'created_at DESC',
    );
    return rows.map(UsageNote.fromMap).toList();
  }

  Future<void> insertUsageNote(UsageNote note) async {
    final db = await database;
    await db.insert('usage_notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeleteUsageNote(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'usage_notes',
      {
        'deleted_at': now,
        'updated_at': now,
        'sync_status': 'pending_delete',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // ============================================================
// SYNC HELPERS
// ============================================================

  Future<List<Gear>> getPendingGear() async {
    final db = await database;
    final rows = await db.query(
      'gear',
      where: 'sync_status != ?',
      whereArgs: ['clean'],
    );
    return rows.map(Gear.fromMap).toList();
  }

  Future<List<UsageNote>> getPendingUsageNotes() async {
    final db = await database;
    final rows = await db.query(
      'usage_notes',
      where: 'sync_status != ?',
      whereArgs: ['clean'],
    );
    return rows.map(UsageNote.fromMap).toList();
  }

  Future<void> markGearClean(String id) async {
    final db = await database;
    await db.update(
      'gear',
      {'sync_status': 'clean'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markUsageNoteClean(String id) async {
    final db = await database;
    await db.update(
      'usage_notes',
      {'sync_status': 'clean'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}