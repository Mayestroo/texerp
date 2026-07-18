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
      unitPrice: (json['unit_price'] as num).toDouble(),
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
      quantitySubmitted: (json['quantity_submitted'] as num).toDouble(),
      quantityApproved: json['quantity_approved'] != null
          ? (json['quantity_approved'] as num).toDouble()
          : null,
      unitPriceSnapshot: (json['unit_price_snapshot'] as num).toDouble(),
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
