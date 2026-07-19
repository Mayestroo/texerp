class PayrollPeriod {
  const PayrollPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.workerCount = 0,
    this.totalGross = 0,
    this.totalFinal = 0,
    this.calculatedAt,
    this.finalizedAt,
    this.createdAt,
  });

  factory PayrollPeriod.fromJson(Map<String, dynamic> json) {
    return PayrollPeriod(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      status: json['status'] as String,
      workerCount: (json['worker_count'] as num?)?.toInt() ?? 0,
      totalGross: (json['total_gross'] as num?)?.toInt() ?? 0,
      totalFinal: (json['total_final'] as num?)?.toInt() ?? 0,
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
      finalizedAt: json['finalized_at'] != null
          ? DateTime.parse(json['finalized_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String status;
  final int workerCount;
  final int totalGross;
  final int totalFinal;
  final DateTime? calculatedAt;
  final DateTime? finalizedAt;
  final DateTime? createdAt;
}

class PayrollCalculation {
  const PayrollCalculation({
    required this.id,
    required this.workerId,
    required this.workerFullName,
    required this.workerCode,
    this.totalPieces = 0,
    this.grossEarnings = 0,
    this.totalBonuses = 0,
    this.totalDeductions = 0,
    this.totalAdvances = 0,
    this.advanceCarryforward = 0,
    this.finalPay = 0,
    this.hasAdjustments = false,
    this.calculationVersion = 1,
    this.entriesCount = 0,
  });

  factory PayrollCalculation.fromJson(Map<String, dynamic> json) {
    return PayrollCalculation(
      id: json['id'] as String,
      workerId: json['worker_id'] as String,
      workerFullName: json['worker_full_name'] as String,
      workerCode: json['worker_code'] as String,
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
      grossEarnings: (json['gross_earnings'] as num?)?.toInt() ?? 0,
      totalBonuses: (json['total_bonuses'] as num?)?.toInt() ?? 0,
      totalDeductions: (json['total_deductions'] as num?)?.toInt() ?? 0,
      totalAdvances: (json['total_advances'] as num?)?.toInt() ?? 0,
      advanceCarryforward: (json['advance_carryforward'] as num?)?.toInt() ?? 0,
      finalPay: (json['final_pay'] as num?)?.toInt() ?? 0,
      hasAdjustments: json['has_adjustments'] as bool? ?? false,
      calculationVersion: (json['calculation_version'] as num?)?.toInt() ?? 1,
      entriesCount: (json['entries_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String workerId;
  final String workerFullName;
  final String workerCode;
  final int totalPieces;
  final int grossEarnings;
  final int totalBonuses;
  final int totalDeductions;
  final int totalAdvances;
  final int advanceCarryforward;
  final int finalPay;
  final bool hasAdjustments;
  final int calculationVersion;
  final int entriesCount;
}

class WorkerCalculationDetail {
  const WorkerCalculationDetail({
    required this.workerId,
    required this.workerFullName,
    required this.workerCode,
    this.departmentName,
    this.operationsBreakdown = const [],
    this.totalPieces = 0,
    this.grossEarnings = 0,
    this.adjustments = const [],
    this.advances = const [],
    this.totalBonuses = 0,
    this.totalDeductions = 0,
    this.totalAdvances = 0,
    this.advanceCarryforward = 0,
    this.finalPay = 0,
    this.calculationVersion = 1,
    this.entriesCount = 0,
  });

  factory WorkerCalculationDetail.fromJson(Map<String, dynamic> json) {
    return WorkerCalculationDetail(
      workerId: json['worker_id'] as String,
      workerFullName: json['worker_full_name'] as String,
      workerCode: json['worker_code'] as String,
      departmentName: json['department_name'] as String?,
      operationsBreakdown: (json['operations_breakdown'] as List<dynamic>?)
              ?.map((e) =>
                  OperationBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalPieces: (json['total_pieces'] as num?)?.toInt() ?? 0,
      grossEarnings: (json['gross_earnings'] as num?)?.toInt() ?? 0,
      adjustments: (json['adjustments'] as List<dynamic>?)
              ?.map(
                  (e) => PayrollAdjustment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      advances: (json['advances'] as List<dynamic>?)
              ?.map((e) => PayrollAdvance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalBonuses: (json['total_bonuses'] as num?)?.toInt() ?? 0,
      totalDeductions: (json['total_deductions'] as num?)?.toInt() ?? 0,
      totalAdvances: (json['total_advances'] as num?)?.toInt() ?? 0,
      advanceCarryforward: (json['advance_carryforward'] as num?)?.toInt() ?? 0,
      finalPay: (json['final_pay'] as num?)?.toInt() ?? 0,
      calculationVersion:
          (json['calculation_version'] as num?)?.toInt() ?? 1,
      entriesCount: (json['entries_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String workerId;
  final String workerFullName;
  final String workerCode;
  final String? departmentName;
  final List<OperationBreakdown> operationsBreakdown;
  final int totalPieces;
  final int grossEarnings;
  final List<PayrollAdjustment> adjustments;
  final List<PayrollAdvance> advances;
  final int totalBonuses;
  final int totalDeductions;
  final int totalAdvances;
  final int advanceCarryforward;
  final int finalPay;
  final int calculationVersion;
  final int entriesCount;
}

class OperationBreakdown {
  const OperationBreakdown({
    required this.operationName,
    required this.quantity,
    required this.unitPrice,
    required this.earnings,
  });

  factory OperationBreakdown.fromJson(Map<String, dynamic> json) {
    return OperationBreakdown(
      operationName: json['operation_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toInt(),
      earnings: (json['earnings'] as num).toInt(),
    );
  }

  final String operationName;
  final int quantity;
  final int unitPrice;
  final int earnings;
}

class PayrollAdjustment {
  const PayrollAdjustment({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
  });

  factory PayrollAdjustment.fromJson(Map<String, dynamic> json) {
    return PayrollAdjustment(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toInt(),
      reason: json['reason'] as String,
    );
  }

  final String id;
  final String type;
  final int amount;
  final String reason;
}

class PayrollAdvance {
  const PayrollAdvance({
    required this.id,
    required this.amount,
    required this.givenDate,
    this.reason,
  });

  factory PayrollAdvance.fromJson(Map<String, dynamic> json) {
    return PayrollAdvance(
      id: json['id'] as String,
      amount: (json['amount'] as num).toInt(),
      givenDate: json['given_date'] as String,
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final int amount;
  final String givenDate;
  final String? reason;
}

class PeriodDetail {
  const PeriodDetail({
    required this.period,
    this.calculations = const [],
    this.pendingEntriesCount = 0,
  });

  factory PeriodDetail.fromJson(Map<String, dynamic> json) {
    return PeriodDetail(
      period: PayrollPeriod.fromJson(json),
      calculations: (json['calculations'] as List<dynamic>?)
              ?.map((e) =>
                  PayrollCalculation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingEntriesCount:
          (json['pending_entries_count'] as num?)?.toInt() ?? 0,
    );
  }

  final PayrollPeriod period;
  final List<PayrollCalculation> calculations;
  final int pendingEntriesCount;
}
