import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/payroll/data/payroll_models.dart';
import 'package:texerp/features/payroll/data/payroll_repository.dart';

abstract class PayrollEvent {
  const PayrollEvent();
}

class PayrollPeriodsLoadRequested extends PayrollEvent {
  const PayrollPeriodsLoadRequested({this.status = 'ALL'});
  final String status;
}

class PayrollPeriodCreateRequested extends PayrollEvent {
  const PayrollPeriodCreateRequested({
    required this.name,
    required this.startDate,
    required this.endDate,
  });
  final String name;
  final String startDate;
  final String endDate;
}

class PayrollPeriodCalculateRequested extends PayrollEvent {
  const PayrollPeriodCalculateRequested({required this.id});
  final String id;
}

class PayrollPeriodFinalizeRequested extends PayrollEvent {
  const PayrollPeriodFinalizeRequested({required this.id});
  final String id;
}

class PayrollPeriodDetailRequested extends PayrollEvent {
  const PayrollPeriodDetailRequested({required this.id});
  final String id;
}

class PayrollWorkerCalculationRequested extends PayrollEvent {
  const PayrollWorkerCalculationRequested({
    required this.periodId,
    required this.workerId,
  });
  final String periodId;
  final String workerId;
}

class PayrollMyPayrollRequested extends PayrollEvent {
  const PayrollMyPayrollRequested();
}

class PayrollResetAction extends PayrollEvent {
  const PayrollResetAction();
}

class PayrollState {
  const PayrollState({
    this.periods = const [],
    this.periodDetail,
    this.workerCalculation,
    this.myPayroll = const [],
    this.total = 0,
    this.isLoading = false,
    this.isCalculating = false,
    this.isFinalizing = false,
    this.error,
    this.actionSuccess = false,
    this.status = 'ALL',
  });

  final List<PayrollPeriod> periods;
  final PeriodDetail? periodDetail;
  final WorkerCalculationDetail? workerCalculation;
  final List<PayrollPeriod> myPayroll;
  final int total;
  final bool isLoading;
  final bool isCalculating;
  final bool isFinalizing;
  final String? error;
  final bool actionSuccess;
  final String status;

  PayrollState copyWith({
    List<PayrollPeriod>? periods,
    PeriodDetail? periodDetail,
    WorkerCalculationDetail? workerCalculation,
    List<PayrollPeriod>? myPayroll,
    int? total,
    bool? isLoading,
    bool? isCalculating,
    bool? isFinalizing,
    String? error,
    bool? actionSuccess,
    String? status,
  }) {
    return PayrollState(
      periods: periods ?? this.periods,
      periodDetail: periodDetail ?? this.periodDetail,
      workerCalculation: workerCalculation ?? this.workerCalculation,
      myPayroll: myPayroll ?? this.myPayroll,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isCalculating: isCalculating ?? this.isCalculating,
      isFinalizing: isFinalizing ?? this.isFinalizing,
      error: error,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      status: status ?? this.status,
    );
  }
}

class PayrollBloc extends Bloc<PayrollEvent, PayrollState> {
  PayrollBloc({required PayrollRepository payrollRepository})
      : _payrollRepository = payrollRepository,
        super(const PayrollState()) {
    on<PayrollPeriodsLoadRequested>(_onLoadPeriods);
    on<PayrollPeriodCreateRequested>(_onCreatePeriod);
    on<PayrollPeriodCalculateRequested>(_onCalculatePeriod);
    on<PayrollPeriodFinalizeRequested>(_onFinalizePeriod);
    on<PayrollPeriodDetailRequested>(_onLoadPeriodDetail);
    on<PayrollWorkerCalculationRequested>(_onLoadWorkerCalculation);
    on<PayrollMyPayrollRequested>(_onLoadMyPayroll);
    on<PayrollResetAction>(_onResetAction);
  }

  final PayrollRepository _payrollRepository;

  Future<void> _onLoadPeriods(
    PayrollPeriodsLoadRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, status: event.status, actionSuccess: false));
    try {
      final (periods, total) =
          await _payrollRepository.fetchPeriods(status: event.status);
      emit(state.copyWith(periods: periods, total: total, isLoading: false, actionSuccess: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreatePeriod(
    PayrollPeriodCreateRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _payrollRepository.createPeriod(
        name: event.name,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(state.copyWith(isLoading: false, actionSuccess: true));
      add(PayrollPeriodsLoadRequested(status: state.status));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCalculatePeriod(
    PayrollPeriodCalculateRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isCalculating: true, error: null));
    try {
      await _payrollRepository.calculatePeriod(event.id);
      emit(state.copyWith(isCalculating: false, actionSuccess: true));
      add(PayrollPeriodsLoadRequested(status: state.status));
    } catch (e) {
      emit(state.copyWith(
        isCalculating: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFinalizePeriod(
    PayrollPeriodFinalizeRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isFinalizing: true, error: null));
    try {
      await _payrollRepository.finalizePeriod(event.id, confirmed: true);
      emit(state.copyWith(isFinalizing: false, actionSuccess: true));
      add(PayrollPeriodsLoadRequested(status: state.status));
    } catch (e) {
      emit(state.copyWith(
        isFinalizing: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadPeriodDetail(
    PayrollPeriodDetailRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final detail = await _payrollRepository.fetchPeriodDetail(event.id);
      emit(state.copyWith(periodDetail: detail, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadWorkerCalculation(
    PayrollWorkerCalculationRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final calc = await _payrollRepository.fetchWorkerCalculation(
        periodId: event.periodId,
        workerId: event.workerId,
      );
      emit(state.copyWith(workerCalculation: calc, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMyPayroll(
    PayrollMyPayrollRequested event,
    Emitter<PayrollState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final periods = await _payrollRepository.fetchMyPayroll();
      emit(state.copyWith(myPayroll: periods, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  void _onResetAction(
    PayrollResetAction event,
    Emitter<PayrollState> emit,
  ) {
    emit(state.copyWith(actionSuccess: false, error: null));
  }
}
