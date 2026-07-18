import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/data/production_repository.dart';

// --- EVENTS ---
abstract class ForemanQueueEvent {
  const ForemanQueueEvent();
}

class ForemanQueueLoadRequested extends ForemanQueueEvent {
  const ForemanQueueLoadRequested();
}

class ForemanQueueApproveRequested extends ForemanQueueEvent {
  const ForemanQueueApproveRequested({required this.id});
  final String id;
}

class ForemanQueueRejectRequested extends ForemanQueueEvent {
  const ForemanQueueRejectRequested({required this.id, required this.reason});
  final String id;
  final String reason;
}

class ForemanQueueCorrectRequested extends ForemanQueueEvent {
  const ForemanQueueCorrectRequested({
    required this.id,
    required this.correctedQuantity,
    this.comment,
  });
  final String id;
  final double correctedQuantity;
  final String? comment;
}

// --- STATES ---
class ForemanQueueState {
  const ForemanQueueState({
    this.pendingEntries = const [],
    this.isLoading = false,
    this.error,
    this.actionInProgressId,
    this.actionError,
    this.actionSuccess = false,
  });

  final List<ProductionEntry> pendingEntries;
  final bool isLoading;
  final String? error;
  final String? actionInProgressId;
  final String? actionError;
  final bool actionSuccess;

  ForemanQueueState copyWith({
    List<ProductionEntry>? pendingEntries,
    bool? isLoading,
    String? error,
    String? actionInProgressId,
    String? actionError,
    bool? actionSuccess,
  }) {
    return ForemanQueueState(
      pendingEntries: pendingEntries ?? this.pendingEntries,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      actionInProgressId: actionInProgressId ?? this.actionInProgressId,
      actionError: actionError ?? this.actionError,
      actionSuccess: actionSuccess ?? this.actionSuccess,
    );
  }
}

// --- BLOC ---
class ForemanQueueBloc extends Bloc<ForemanQueueEvent, ForemanQueueState> {
  ForemanQueueBloc({required ProductionRepository productionRepository})
      : _productionRepository = productionRepository,
        super(const ForemanQueueState()) {
    on<ForemanQueueLoadRequested>(_onLoadQueue);
    on<ForemanQueueApproveRequested>(_onApprove);
    on<ForemanQueueRejectRequested>(_onReject);
    on<ForemanQueueCorrectRequested>(_onCorrect);
  }

  final ProductionRepository _productionRepository;

  Future<void> _onLoadQueue(
    ForemanQueueLoadRequested event,
    Emitter<ForemanQueueState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, actionSuccess: false));
    try {
      final entries = await _productionRepository.fetchPendingEntriesForForeman();
      emit(state.copyWith(
        pendingEntries: entries,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onApprove(
    ForemanQueueApproveRequested event,
    Emitter<ForemanQueueState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _productionRepository.approveEntry(event.id);
      final updatedList = state.pendingEntries.where((entry) => entry.id != event.id).toList();
      emit(state.copyWith(
        pendingEntries: updatedList,
        actionInProgressId: null,
        actionSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionInProgressId: null,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onReject(
    ForemanQueueRejectRequested event,
    Emitter<ForemanQueueState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _productionRepository.rejectEntry(event.id, event.reason);
      final updatedList = state.pendingEntries.where((entry) => entry.id != event.id).toList();
      emit(state.copyWith(
        pendingEntries: updatedList,
        actionInProgressId: null,
        actionSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionInProgressId: null,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onCorrect(
    ForemanQueueCorrectRequested event,
    Emitter<ForemanQueueState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _productionRepository.correctAndApproveEntry(
        id: event.id,
        correctedQuantity: event.correctedQuantity,
        comment: event.comment,
      );
      final updatedList = state.pendingEntries.where((entry) => entry.id != event.id).toList();
      emit(state.copyWith(
        pendingEntries: updatedList,
        actionInProgressId: null,
        actionSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionInProgressId: null,
        actionError: e.toString(),
      ));
    }
  }
}
