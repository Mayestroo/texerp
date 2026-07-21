double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}

/// A warehouse material with its current stock balance.
class Material {
  const Material({
    required this.id,
    required this.code,
    required this.name,
    this.category,
    required this.unit,
    this.minQuantity,
    required this.balance,
    required this.isLowStock,
    required this.isActive,
    required this.createdAt,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      unit: json['unit'] as String,
      minQuantity: json['min_quantity'] != null
          ? _toDouble(json['min_quantity'])
          : null,
      balance: _toDouble(json['balance']),
      isLowStock: json['is_low_stock'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String code;
  final String name;
  final String? category;
  final String unit;
  final double? minQuantity;
  final double balance;
  final bool isLowStock;
  final bool isActive;
  final DateTime createdAt;
}

/// A single stock movement (receipt, issuance, or correction).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.materialId,
    required this.type,
    required this.quantity,
    required this.unitSnapshot,
    this.supplierName,
    this.destination,
    required this.movementDate,
    this.note,
    required this.isFlagged,
    required this.recordedBy,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      type: json['type'] as String,
      quantity: _toDouble(json['quantity']),
      unitSnapshot: json['unit_snapshot'] as String,
      supplierName: json['supplier_name'] as String?,
      destination: json['destination'] as String?,
      movementDate: json['movement_date'] != null
          ? DateTime.parse(json['movement_date'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
      recordedBy: json['recorded_by'] as String? ?? '',
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String materialId;
  final String type;
  final double quantity;
  final String unitSnapshot;
  final String? supplierName;
  final String? destination;
  final DateTime movementDate;
  final String? note;
  final bool isFlagged;
  final String recordedBy;
  final DateTime createdAt;
}

/// Snapshot of a material's current balance.
class MaterialBalance {
  const MaterialBalance({
    required this.materialId,
    required this.balance,
    required this.unit,
    this.updatedAt,
  });

  factory MaterialBalance.fromJson(Map<String, dynamic> json) {
    return MaterialBalance(
      materialId: json['material_id'] as String? ?? json['id'] as String? ?? '',
      balance: _toDouble(json['balance']),
      unit: json['unit'] as String? ?? '',
      updatedAt: _toDateTime(json['updated_at']),
    );
  }

  final String materialId;
  final double balance;
  final String unit;
  final DateTime? updatedAt;
}
