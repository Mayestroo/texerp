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

class ForemanQueueToggleSelectionMode extends ForemanQueueEvent {
  const ForemanQueueToggleSelectionMode({this.enabled});
  final bool? enabled;
}

class ForemanQueueToggleItemSelection extends ForemanQueueEvent {
  const ForemanQueueToggleItemSelection({required this.id});
  final String id;
}

class ForemanQueueSelectAll extends ForemanQueueEvent {
  const ForemanQueueSelectAll();
}

class ForemanQueueClearSelection extends ForemanQueueEvent {
  const ForemanQueueClearSelection();
}

class ForemanQueueBulkApproveRequested extends ForemanQueueEvent {
  const ForemanQueueBulkApproveRequested();
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
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.isBulkApproving = false,
  });

  final List<ProductionEntry> pendingEntries;
  final bool isLoading;
  final String? error;
  final String? actionInProgressId;
  final String? actionError;
  final bool actionSuccess;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isBulkApproving;

  ForemanQueueState copyWith({
    List<ProductionEntry>? pendingEntries,
    bool? isLoading,
    String? error,
    Object? actionInProgressId = const Object(),
    Object? actionError = const Object(),
    bool? actionSuccess,
    bool? isSelectionMode,
    Set<String>? selectedIds,
    bool? isBulkApproving,
  }) {
    return ForemanQueueState(
      pendingEntries: pendingEntries ?? this.pendingEntries,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      actionInProgressId: actionInProgressId == const Object()
          ? this.actionInProgressId
          : (actionInProgressId as String?),
      actionError: actionError == const Object()
          ? this.actionError
          : (actionError as String?),
      actionSuccess: actionSuccess ?? this.actionSuccess,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      isBulkApproving: isBulkApproving ?? this.isBulkApproving,
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
    on<ForemanQueueToggleSelectionMode>(_onToggleSelectionMode);
    on<ForemanQueueToggleItemSelection>(_onToggleItemSelection);
    on<ForemanQueueSelectAll>(_onSelectAll);
    on<ForemanQueueClearSelection>(_onClearSelection);
    on<ForemanQueueBulkApproveRequested>(_onBulkApprove);
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
        selectedIds: {},
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
      final updatedSelected = Set<String>.from(state.selectedIds)..remove(event.id);
      emit(state.copyWith(
        pendingEntries: updatedList,
        selectedIds: updatedSelected,
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
      final updatedSelected = Set<String>.from(state.selectedIds)..remove(event.id);
      emit(state.copyWith(
        pendingEntries: updatedList,
        selectedIds: updatedSelected,
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
      final updatedSelected = Set<String>.from(state.selectedIds)..remove(event.id);
      emit(state.copyWith(
        pendingEntries: updatedList,
        selectedIds: updatedSelected,
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

  void _onToggleSelectionMode(
    ForemanQueueToggleSelectionMode event,
    Emitter<ForemanQueueState> emit,
  ) {
    final targetMode = event.enabled ?? !state.isSelectionMode;
    emit(state.copyWith(
      isSelectionMode: targetMode,
      selectedIds: targetMode ? state.selectedIds : {},
    ));
  }

  void _onToggleItemSelection(
    ForemanQueueToggleItemSelection event,
    Emitter<ForemanQueueState> emit,
  ) {
    final updated = Set<String>.from(state.selectedIds);
    if (updated.contains(event.id)) {
      updated.remove(event.id);
    } else {
      if (updated.length >= 50) {
        emit(state.copyWith(actionError: 'Ko\'pi bilan 50 ta elementni tanlash mumkin'));
        return;
      }
      updated.add(event.id);
    }
    emit(state.copyWith(selectedIds: updated, isSelectionMode: true));
  }

  void _onSelectAll(
    ForemanQueueSelectAll event,
    Emitter<ForemanQueueState> emit,
  ) {
    final available = state.pendingEntries.map((e) => e.id).take(50).toSet();
    emit(state.copyWith(
      isSelectionMode: true,
      selectedIds: available,
    ));
  }

  void _onClearSelection(
    ForemanQueueClearSelection event,
    Emitter<ForemanQueueState> emit,
  ) {
    emit(state.copyWith(
      selectedIds: {},
      isSelectionMode: false,
    ));
  }

  Future<void> _onBulkApprove(
    ForemanQueueBulkApproveRequested event,
    Emitter<ForemanQueueState> emit,
  ) async {
    if (state.selectedIds.isEmpty) return;
    emit(state.copyWith(
      isBulkApproving: true,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final idsList = state.selectedIds.toList();
      await _productionRepository.bulkApproveEntries(idsList);
      final remaining = state.pendingEntries
          .where((entry) => !state.selectedIds.contains(entry.id))
          .toList();
      emit(state.copyWith(
        pendingEntries: remaining,
        selectedIds: {},
        isSelectionMode: false,
        isBulkApproving: false,
        actionSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isBulkApproving: false,
        actionError: e.toString(),
      ));
    }
  }
}
