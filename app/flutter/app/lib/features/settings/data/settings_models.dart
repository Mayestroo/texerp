int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    this.name,
    this.timezone,
    this.language,
    this.currency,
    this.backDateWindowDays = 3,
    this.suspiciousQuantityMultiplier = 3,
    this.payrollMinPay = 0,
    this.duplicateWindowMinutes = 60,
    this.stockNegativeMode = 'HARD_BLOCK',
  });

  factory TenantSettings.fromJson(Map<String, dynamic> json) {
    return TenantSettings(
      tenantId: json['organization_id'] as String? ??
          json['tenant_id'] as String? ??
          '',
      name: json['name'] as String?,
      timezone: json['timezone'] as String?,
      language: json['language'] as String?,
      currency: json['currency'] as String?,
      backDateWindowDays: _toInt(json['back_date_window_days']),
      suspiciousQuantityMultiplier: _toInt(json['suspicious_quantity_multiplier']),
      payrollMinPay: _toInt(json['payroll_min_pay']),
      duplicateWindowMinutes: _toInt(json['duplicate_window_minutes']),
      stockNegativeMode: json['stock_negative_mode'] as String? ?? 'HARD_BLOCK',
    );
  }

  final String tenantId;
  final String? name;
  final String? timezone;
  final String? language;
  final String? currency;
  final int backDateWindowDays;
  final int suspiciousQuantityMultiplier;
  final int payrollMinPay;
  final int duplicateWindowMinutes;
  final String stockNegativeMode;

  TenantSettings copyWith({
    String? tenantId,
    String? name,
    String? timezone,
    String? language,
    String? currency,
    int? backDateWindowDays,
    int? suspiciousQuantityMultiplier,
    int? payrollMinPay,
    int? duplicateWindowMinutes,
    String? stockNegativeMode,
  }) {
    return TenantSettings(
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      backDateWindowDays: backDateWindowDays ?? this.backDateWindowDays,
      suspiciousQuantityMultiplier:
          suspiciousQuantityMultiplier ?? this.suspiciousQuantityMultiplier,
      payrollMinPay: payrollMinPay ?? this.payrollMinPay,
      duplicateWindowMinutes: duplicateWindowMinutes ?? this.duplicateWindowMinutes,
      stockNegativeMode: stockNegativeMode ?? this.stockNegativeMode,
    );
  }
}
