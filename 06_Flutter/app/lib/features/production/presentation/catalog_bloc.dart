import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/data/production_repository.dart';

// --- EVENTS ---
abstract class CatalogEvent {
  const CatalogEvent();
}

class CatalogLoadRequested extends CatalogEvent {
  const CatalogLoadRequested({this.status = 'ACTIVE', this.search});
  final String status;
  final String? search;
}

class CatalogCreateRequested extends CatalogEvent {
  const CatalogCreateRequested({
    required this.name,
    this.code,
    required this.unit,
    required this.unitPrice,
  });
  final String name;
  final String? code;
  final String unit;
  final double unitPrice;
}

class CatalogUpdateRequested extends CatalogEvent {
  const CatalogUpdateRequested({
    required this.id,
    this.name,
    this.code,
    this.unitPrice,
  });
  final String id;
  final String? name;
  final String? code;
  final double? unitPrice;
}

class CatalogToggleStatusRequested extends CatalogEvent {
  const CatalogToggleStatusRequested({
    required this.id,
    required this.currentActive,
  });
  final String id;
  final bool currentActive;
}

// --- STATES ---
class CatalogState {
  const CatalogState({
    this.operations = const [],
    this.isLoading = false,
    this.error,
    this.status = 'ACTIVE',
    this.actionInProgressId,
    this.actionSuccess = false,
    this.actionError,
  });

  final List<Operation> operations;
  final bool isLoading;
  final String? error;
  final String status;
  final String? actionInProgressId;
  final bool actionSuccess;
  final String? actionError;

  CatalogState copyWith({
    List<Operation>? operations,
    bool? isLoading,
    String? error,
    String? status,
    String? actionInProgressId,
    bool? actionSuccess,
    String? actionError,
  }) {
    return CatalogState(
      operations: operations ?? this.operations,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      status: status ?? this.status,
      actionInProgressId: actionInProgressId ?? this.actionInProgressId,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      actionError: actionError ?? this.actionError,
    );
  }
}

// --- BLOC ---
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required ProductionRepository productionRepository})
      : _productionRepository = productionRepository,
        super(const CatalogState()) {
    on<CatalogLoadRequested>(_onLoadCatalog);
    on<CatalogCreateRequested>(_onCreateOperation);
    on<CatalogUpdateRequested>(_onUpdateOperation);
    on<CatalogToggleStatusRequested>(_onToggleStatus);
  }

  final ProductionRepository _productionRepository;

  Future<void> _onLoadCatalog(
    CatalogLoadRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      error: null,
      status: event.status,
      actionSuccess: false,
    ));
    try {
      final operations = await _productionRepository.fetchOperations(
        status: event.status,
        search: event.search,
      );
      emit(state.copyWith(
        operations: operations,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateOperation(
    CatalogCreateRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: 'CREATE',
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final newOp = await _productionRepository.createOperation(
        name: event.name,
        code: event.code,
        unit: event.unit,
        unitPrice: event.unitPrice,
      );

      // If we are currently viewing ACTIVE, insert the new active operation into list
      final updatedList = List<Operation>.from(state.operations);
      if (state.status == 'ACTIVE' || state.status == 'ALL') {
        updatedList.insert(0, newOp);
      }

      emit(state.copyWith(
        operations: updatedList,
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

  Future<void> _onUpdateOperation(
    CatalogUpdateRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final updatedOp = await _productionRepository.updateOperation(
        id: event.id,
        name: event.name,
        code: event.code,
        unitPrice: event.unitPrice,
      );

      final updatedList = state.operations.map((op) {
        return op.id == event.id ? updatedOp : op;
      }).toList();

      emit(state.copyWith(
        operations: updatedList,
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

  Future<void> _onToggleStatus(
    CatalogToggleStatusRequested event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      if (event.currentActive) {
        await _productionRepository.deactivateOperation(event.id);
      } else {
        await _productionRepository.activateOperation(event.id);
      }

      // Remove from list since its status changed (if filter is not ALL)
      final updatedList = List<Operation>.from(state.operations);
      if (state.status != 'ALL') {
        updatedList.removeWhere((op) => op.id == event.id);
      } else {
        // Toggle the isActive flag in list
        final index = updatedList.indexWhere((op) => op.id == event.id);
        if (index != -1) {
          final old = updatedList[index];
          updatedList[index] = Operation(
            id: old.id,
            name: old.name,
            code: old.code,
            unit: old.unit,
            unitPrice: old.unitPrice,
            currency: old.currency,
            isActive: !event.currentActive,
          );
        }
      }

      emit(state.copyWith(
        operations: updatedList,
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
