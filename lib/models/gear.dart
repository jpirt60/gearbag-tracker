class Gear {
  final int id;
  String type;         // 'bat' | 'glove' | 'cleats' | 'bag' | 'balls' | 'other'
  String brand;
  String model;
  String status;       // 'active' | 'benched'
  String notes;
  List<String> usageNotes;

  Gear({
    required this.id,
    required this.type,
    required this.brand,
    required this.model,
    required this.status,
    required this.notes,
    List<String>? usageNotes,
  }) : usageNotes = usageNotes ?? [];

  Gear copyWith({
    int? id,
    String? type,
    String? brand,
    String? model,
    String? status,
    String? notes,
    List<String>? usageNotes,
  }) {
    return Gear(
      id: id ?? this.id,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      usageNotes: usageNotes ?? List<String>.from(this.usageNotes),
    );
  }

  // --- Persistence ---

  factory Gear.fromJson(Map<String, dynamic> json) => Gear(
    id: json['id'] as int,
    type: json['type'] as String,
    brand: json['brand'] as String,
    model: json['model'] as String,
    status: json['status'] as String,
    notes: json['notes'] as String? ?? '',
    usageNotes: (json['usageNotes'] as List?)?.cast<String>() ?? <String>[],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'brand': brand,
    'model': model,
    'status': status,
    'notes': notes,
    'usageNotes': usageNotes,
  };
}
