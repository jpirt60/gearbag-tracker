class UsageNote {
  final String id;
  final String gearId;
  final String userId;
  String text;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  String syncStatus;

  UsageNote({
    required this.id,
    required this.gearId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'clean',
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'gear_id': gearId,
    'user_id': userId,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory UsageNote.fromMap(Map<String, Object?> map) => UsageNote(
    id: map['id'] as String,
    gearId: map['gear_id'] as String,
    userId: map['user_id'] as String,
    text: map['text'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'] as String)
        : null,
    syncStatus: map['sync_status'] as String? ?? 'clean',
  );
}