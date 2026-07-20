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

class Operation {
  const Operation({
    required this.id,
    required this.name,
    this.code,
    required this.unit,
    required this.unitPrice,
    required this.currency,
    required this.isActive,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      unit: json['unit'] as String,
      unitPrice: _toDouble(json['unit_price']),
      currency: json['currency'] as String? ?? 'UZS',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String? code;
  final String unit;
  final double unitPrice;
  final String currency;
  final bool isActive;
}

class WorkerInfo {
  const WorkerInfo({
    required this.id,
    required this.fullName,
    required this.workerCode,
  });

  factory WorkerInfo.fromJson(Map<String, dynamic> json) {
    return WorkerInfo(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      workerCode: json['worker_code'] as String,
    );
  }

  final String id;
  final String fullName;
  final String workerCode;
}

class ProductionEntry {
  const ProductionEntry({
    required this.id,
    required this.status,
    required this.operationNameSnapshot,
    required this.quantitySubmitted,
    this.quantityApproved,
    required this.unitPriceSnapshot,
    required this.recordDate,
    this.workerNote,
    required this.submittedAt,
    this.rejectionReason,
    this.worker,
  });

  factory ProductionEntry.fromJson(Map<String, dynamic> json) {
    return ProductionEntry(
      id: json['id'] as String,
      status: json['status'] as String,
      operationNameSnapshot: json['operation_name_snapshot'] as String,
      quantitySubmitted: _toDouble(json['quantity_submitted']),
      quantityApproved: json['quantity_approved'] != null
          ? _toDouble(json['quantity_approved'])
          : null,
      unitPriceSnapshot: _toDouble(json['unit_price_snapshot']),
      recordDate: json['record_date'] as String,
      workerNote: json['worker_note'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      worker: json['worker'] != null
          ? WorkerInfo.fromJson(json['worker'] as Map<String, dynamic>)
          : null,
    );
  }

  final String id;
  final String status;
  final String operationNameSnapshot;
  final double quantitySubmitted;
  final double? quantityApproved;
  final double unitPriceSnapshot;
  final String recordDate;
  final String? workerNote;
  final DateTime submittedAt;
  final String? rejectionReason;
  final WorkerInfo? worker;
}

class ProductionSummary {
  const ProductionSummary({
    required this.todayEntriesCount,
    required this.todayTotalQuantity,
    required this.pendingEntriesCount,
    required this.approvedEntriesCount,
    required this.rejectedEntriesCount,
  });

  factory ProductionSummary.fromJson(Map<String, dynamic> json) {
    return ProductionSummary(
      todayEntriesCount: _toInt(json['todayEntriesCount']),
      todayTotalQuantity: _toInt(json['todayTotalQuantity']),
      pendingEntriesCount: _toInt(json['pendingEntriesCount']),
      approvedEntriesCount: _toInt(json['approvedEntriesCount']),
      rejectedEntriesCount: _toInt(json['rejectedEntriesCount']),
    );
  }

  final int todayEntriesCount;
  final int todayTotalQuantity;
  final int pendingEntriesCount;
  final int approvedEntriesCount;
  final int rejectedEntriesCount;
}
