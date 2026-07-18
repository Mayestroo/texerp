import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/data/production_repository.dart';

// --- EVENTS ---
abstract class ProductionEvent {
  const ProductionEvent();
}

class ProductionLoadOperationsRequested extends ProductionEvent {
  const ProductionLoadOperationsRequested();
}

class ProductionSubmitRequested extends ProductionEvent {
  const ProductionSubmitRequested({
    required this.operationId,
    required this.quantity,
    required this.recordDate,
    this.workerNote,
  });

  final String operationId;
  final double quantity;
  final String recordDate;
  final String? workerNote;
}

class ProductionLoadHistoryRequested extends ProductionEvent {
  const ProductionLoadHistoryRequested({this.refresh = false});

  final bool refresh;
}

// --- STATES ---
enum ProductionSubmitStatus { initial, loading, success, failure }

class ProductionState {
  const ProductionState({
    this.operations = const [],
    this.operationsLoading = false,
    this.operationsError,
    this.history = const [],
    this.historyLoading = false,
    this.historyError,
    this.submitStatus = ProductionSubmitStatus.initial,
    this.submitError,
  });

  final List<Operation> operations;
  final bool operationsLoading;
  final String? operationsError;
  final List<ProductionEntry> history;
  final bool historyLoading;
  final String? historyError;
  final ProductionSubmitStatus submitStatus;
  final String? submitError;

  ProductionState copyWith({
    List<Operation>? operations,
    bool? operationsLoading,
    String? operationsError,
    List<ProductionEntry>? history,
    bool? historyLoading,
    String? historyError,
    ProductionSubmitStatus? submitStatus,
    String? submitError,
  }) {
    return ProductionState(
      operations: operations ?? this.operations,
      operationsLoading: operationsLoading ?? this.operationsLoading,
      operationsError: operationsError ?? this.operationsError,
      history: history ?? this.history,
      historyLoading: historyLoading ?? this.historyLoading,
      historyError: historyError ?? this.historyError,
      submitStatus: submitStatus ?? this.submitStatus,
      submitError: submitError ?? this.submitError,
    );
  }
}

// --- BLOC ---
class ProductionBloc extends Bloc<ProductionEvent, ProductionState> {
  ProductionBloc({required ProductionRepository productionRepository})
      : _productionRepository = productionRepository,
        super(const ProductionState()) {
    on<ProductionLoadOperationsRequested>(_onLoadOperations);
    on<ProductionSubmitRequested>(_onSubmit);
    on<ProductionLoadHistoryRequested>(_onLoadHistory);
  }

  final ProductionRepository _productionRepository;

  Future<void> _onLoadOperations(
    ProductionLoadOperationsRequested event,
    Emitter<ProductionState> emit,
  ) async {
    emit(state.copyWith(
      operationsLoading: true,
      operationsError: null,
    ));
    try {
      final ops = await _productionRepository.fetchOperations();
      emit(state.copyWith(
        operations: ops,
        operationsLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        operationsLoading: false,
        operationsError: e.toString(),
      ));
    }
  }

  Future<void> _onSubmit(
    ProductionSubmitRequested event,
    Emitter<ProductionState> emit,
  ) async {
    emit(state.copyWith(
      submitStatus: ProductionSubmitStatus.loading,
      submitError: null,
    ));
    try {
      final newEntry = await _productionRepository.createProductionEntry(
        operationId: event.operationId,
        quantity: event.quantity,
        recordDate: event.recordDate,
        workerNote: event.workerNote,
      );
      // Prepend to local history if history is already loaded
      final updatedHistory = List<ProductionEntry>.from(state.history)..insert(0, newEntry);
      emit(state.copyWith(
        submitStatus: ProductionSubmitStatus.success,
        history: updatedHistory,
      ));
    } catch (e) {
      emit(state.copyWith(
        submitStatus: ProductionSubmitStatus.failure,
        submitError: e.toString(),
      ));
    }
  }

  Future<void> _onLoadHistory(
    ProductionLoadHistoryRequested event,
    Emitter<ProductionState> emit,
  ) async {
    emit(state.copyWith(
      historyLoading: true,
      historyError: null,
    ));
    try {
      final (entries, _) = await _productionRepository.fetchMyEntries();
      emit(state.copyWith(
        history: entries,
        historyLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        historyLoading: false,
        historyError: e.toString(),
      ));
    }
  }
}
