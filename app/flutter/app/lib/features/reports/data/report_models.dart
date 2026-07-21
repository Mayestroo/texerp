int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class ReportPeriod {
  const ReportPeriod({
    required this.from,
    required this.to,
  });

  factory ReportPeriod.fromJson(Map<String, dynamic> json) {
    return ReportPeriod(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
    );
  }

  final String from;
  final String to;
}

class Pagination {
  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: _toInt(json['page']),
      limit: _toInt(json['limit']),
      total: _toInt(json['total']),
      totalPages: _toInt(json['total_pages']),
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
}

class ReportRow {
  const ReportRow({
    required this.groupBy,
    required this.groupIdentity,
    required this.totalPieces,
    required this.grossEarnings,
    required this.recordsCount,
    this.workersCount,
    this.operationsCount,
  });

  factory ReportRow.fromJson(
    Map<String, dynamic> json, {
    required String groupBy,
  }) {
    final Map<String, dynamic> identity;
    if (groupBy == 'date') {
      identity = {'date': json['date'] ?? ''};
    } else {
      identity = (json[groupBy] as Map<String, dynamic>?) ?? const {};
    }

    return ReportRow(
      groupBy: groupBy,
      groupIdentity: identity,
      totalPieces: _toInt(json['total_pieces']),
      grossEarnings: _toInt(json['gross_earnings']),
      recordsCount: _toInt(json['records_count']),
      workersCount: json['workers_count'] != null
          ? _toInt(json['workers_count'])
          : null,
      operationsCount: json['operations_count'] != null
          ? _toInt(json['operations_count'])
          : null,
    );
  }

  final String groupBy;
  final Map<String, dynamic> groupIdentity;
  final int totalPieces;
  final int grossEarnings;
  final int recordsCount;
  final int? workersCount;
  final int? operationsCount;
}

class ProductionReport {
  const ProductionReport({
    required this.period,
    required this.totalPieces,
    required this.totalEarnings,
    required this.rows,
    required this.pagination,
  });

  factory ProductionReport.fromJson(
    Map<String, dynamic> json, {
    required String groupBy,
    Map<String, dynamic>? pagination,
  }) {
    final rowsJson = json['rows'] as List<dynamic>? ?? const [];
    return ProductionReport(
      period: ReportPeriod.fromJson(json['period'] as Map<String, dynamic>),
      totalPieces: _toInt(json['total_pieces']),
      totalEarnings: _toInt(json['total_earnings']),
      rows: rowsJson
          .map((e) => ReportRow.fromJson(
                e as Map<String, dynamic>,
                groupBy: groupBy,
              ))
          .toList(),
      pagination: pagination != null
          ? Pagination.fromJson(pagination)
          : const Pagination(
              page: 1,
              limit: 25,
              total: 0,
              totalPages: 0,
              hasNext: false,
              hasPrev: false,
            ),
    );
  }

  final ReportPeriod period;
  final int totalPieces;
  final int totalEarnings;
  final List<ReportRow> rows;
  final Pagination pagination;
}

class ExportStatus {
  const ExportStatus({
    required this.status,
    this.downloadUrl,
    this.fileSizeBytes,
    this.expiresAt,
  });

  factory ExportStatus.fromJson(Map<String, dynamic> json) {
    return ExportStatus(
      status: json['status'] as String? ?? 'FAILED',
      downloadUrl: json['download_url'] as String?,
      fileSizeBytes: json['file_size_bytes'] != null
          ? _toInt(json['file_size_bytes'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  final String status;
  final String? downloadUrl;
  final int? fileSizeBytes;
  final DateTime? expiresAt;
}
