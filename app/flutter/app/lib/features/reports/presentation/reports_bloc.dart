import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/reports/data/report_models.dart';
import 'package:texerp/features/reports/data/reports_repository.dart';

// --- EVENTS ---
abstract class ReportsEvent {
  const ReportsEvent();
}

class ReportsFiltersChanged extends ReportsEvent {
  const ReportsFiltersChanged({
    this.dateFrom,
    this.dateTo,
    this.groupBy,
    this.workerId,
    this.foremanId,
    this.operationId,
    this.departmentId,
  });

  final String? dateFrom;
  final String? dateTo;
  final String? groupBy;
  final String? workerId;
  final String? foremanId;
  final String? operationId;
  final String? departmentId;
}

class ReportsLoadRequested extends ReportsEvent {
  const ReportsLoadRequested({this.refresh = false});

  final bool refresh;
}

class ReportsExportRequested extends ReportsEvent {
  const ReportsExportRequested();
}

class ReportsExportPollTicked extends ReportsEvent {
  const ReportsExportPollTicked({required this.exportId});

  final String exportId;
}

class ReportsExportReset extends ReportsEvent {
  const ReportsExportReset();
}

// --- STATES ---
class ReportsState {
  const ReportsState({
    required this.dateFrom,
    required this.dateTo,
    this.groupBy = 'worker',
    this.workerId,
    this.foremanId,
    this.operationId,
    this.departmentId,
    this.report,
    this.isLoading = false,
    this.isExporting = false,
    this.exportId,
    this.exportStatus,
    this.error,
    this.exportError,
  });

  factory ReportsState.initial() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    return ReportsState(
      dateFrom: _formatDate(firstDay),
      dateTo: _formatDate(now),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  final String dateFrom;
  final String dateTo;
  final String groupBy;
  final String? workerId;
  final String? foremanId;
  final String? operationId;
  final String? departmentId;
  final ProductionReport? report;
  final bool isLoading;
  final bool isExporting;
  final String? exportId;
  final ExportStatus? exportStatus;
  final String? error;
  final String? exportError;

  ReportsState copyWith({
    String? dateFrom,
    String? dateTo,
    String? groupBy,
    Object? workerId = const Object(),
    Object? foremanId = const Object(),
    Object? operationId = const Object(),
    Object? departmentId = const Object(),
    ProductionReport? report,
    bool? isLoading,
    bool? isExporting,
    Object? exportId = const Object(),
    ExportStatus? exportStatus,
    String? error,
    String? exportError,
  }) {
    return ReportsState(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      groupBy: groupBy ?? this.groupBy,
      workerId: workerId == const Object()
          ? this.workerId
          : (workerId as String?),
      foremanId: foremanId == const Object()
          ? this.foremanId
          : (foremanId as String?),
      operationId: operationId == const Object()
          ? this.operationId
          : (operationId as String?),
      departmentId: departmentId == const Object()
          ? this.departmentId
          : (departmentId as String?),
      report: report ?? this.report,
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      exportId: exportId == const Object()
          ? this.exportId
          : (exportId as String?),
      exportStatus: exportStatus ?? this.exportStatus,
      error: error,
      exportError: exportError,
    );
  }
}

// --- BLOC ---
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc({required ReportsRepository reportsRepository})
      : _reportsRepository = reportsRepository,
        super(ReportsState.initial()) {
    on<ReportsFiltersChanged>(_onFiltersChanged);
    on<ReportsLoadRequested>(_onLoad);
    on<ReportsExportRequested>(_onExport);
    on<ReportsExportPollTicked>(_onPollTicked);
    on<ReportsExportReset>(_onResetExport);
  }

  final ReportsRepository _reportsRepository;

  void _onFiltersChanged(
    ReportsFiltersChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      groupBy: event.groupBy,
      workerId: event.workerId,
      foremanId: event.foremanId,
      operationId: event.operationId,
      departmentId: event.departmentId,
      error: null,
    ));
  }

  Future<void> _onLoad(
    ReportsLoadRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final report = await _reportsRepository.fetchProductionReport(
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        groupBy: state.groupBy,
        workerId: state.workerId,
        foremanId: state.foremanId,
        operationId: state.operationId,
        departmentId: state.departmentId,
      );
      emit(state.copyWith(
        report: report,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onExport(
    ReportsExportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(
      isExporting: true,
      exportId: null,
      exportStatus: null,
      exportError: null,
    ));
    try {
      final exportId = await _reportsRepository.queueExport(
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        groupBy: state.groupBy,
        workerId: state.workerId,
        foremanId: state.foremanId,
        operationId: state.operationId,
        departmentId: state.departmentId,
      );
      emit(state.copyWith(exportId: exportId));
      add(ReportsExportPollTicked(exportId: exportId));
    } catch (e) {
      emit(state.copyWith(
        isExporting: false,
        exportError: e.toString(),
      ));
    }
  }

  Future<void> _onPollTicked(
    ReportsExportPollTicked event,
    Emitter<ReportsState> emit,
  ) async {
    try {
      final status = await _reportsRepository.getExportStatus(event.exportId);
      final isDone =
          status.status == 'READY' || status.status == 'FAILED';
      emit(state.copyWith(
        exportStatus: status,
        isExporting: !isDone,
        exportError: status.status == 'FAILED'
            ? 'Excel yuklab bo\'lmadi'
            : null,
      ));
      if (!isDone && !isClosed) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!isClosed) {
          add(ReportsExportPollTicked(exportId: event.exportId));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        isExporting: false,
        exportError: e.toString(),
      ));
    }
  }

  void _onResetExport(
    ReportsExportReset event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      isExporting: false,
      exportId: null,
      exportStatus: null,
      exportError: null,
    ));
  }
}
