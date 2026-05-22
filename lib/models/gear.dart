class Gear {
  final String id;           // UUID
  final String userId;
  String type;
  String brand;
  String model;
  String status;
  String? notes;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  String syncStatus;         // 'clean' | 'pending_create' | 'pending_update' | 'pending_delete'

  Gear({
    required this.id,
    required this.userId,
    required this.type,
    required this.brand,
    required this.model,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'clean',
  });

  Gear copyWith({
    String? type,
    String? brand,
    String? model,
    String? status,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return Gear(
      id: id,
      userId: userId,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // --- sqflite serialization ---

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'brand': brand,
    'model': model,
    'status': status,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory Gear.fromMap(Map<String, Object?> map) => Gear(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    type: map['type'] as String,
    brand: map['brand'] as String,
    model: map['model'] as String,
    status: map['status'] as String,
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    deletedAt: map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'] as String)
        : null,
    syncStatus: map['sync_status'] as String? ?? 'clean',
  );
}