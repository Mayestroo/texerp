import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/warehouse/data/warehouse_models.dart';
import 'package:texerp/features/warehouse/data/warehouse_repository.dart';

// --- EVENTS ---
abstract class WarehouseEvent {
  const WarehouseEvent();
}

class WarehouseMaterialsLoadRequested extends WarehouseEvent {
  const WarehouseMaterialsLoadRequested({
    this.refresh = false,
    this.isActive,
    this.category,
    this.search,
  });

  final bool refresh;
  final bool? isActive;
  final String? category;
  final String? search;
}

class WarehouseMaterialDetailRequested extends WarehouseEvent {
  const WarehouseMaterialDetailRequested({
    required this.materialId,
    this.material,
  });

  final String materialId;
  final Material? material;
}

class WarehouseMaterialCreateRequested extends WarehouseEvent {
  const WarehouseMaterialCreateRequested({
    required this.code,
    required this.name,
    this.category,
    required this.unit,
    this.minQuantity,
  });

  final String code;
  final String name;
  final String? category;
  final String unit;
  final double? minQuantity;
}

class WarehouseMaterialUpdateRequested extends WarehouseEvent {
  const WarehouseMaterialUpdateRequested({
    required this.id,
    this.name,
    this.category,
    this.minQuantity,
  });

  final String id;
  final String? name;
  final String? category;
  final double? minQuantity;
}

class WarehouseMaterialDeactivateRequested extends WarehouseEvent {
  const WarehouseMaterialDeactivateRequested({required this.id});

  final String id;
}

class WarehouseMaterialActivateRequested extends WarehouseEvent {
  const WarehouseMaterialActivateRequested({required this.id});

  final String id;
}

class WarehouseReceiptRequested extends WarehouseEvent {
  const WarehouseReceiptRequested({
    required this.materialId,
    required this.quantity,
    required this.movementDate,
    this.supplierName,
    this.note,
  });

  final String materialId;
  final double quantity;
  final DateTime movementDate;
  final String? supplierName;
  final String? note;
}

class WarehouseIssuanceRequested extends WarehouseEvent {
  const WarehouseIssuanceRequested({
    required this.materialId,
    required this.quantity,
    required this.movementDate,
    this.destination,
    this.note,
  });

  final String materialId;
  final double quantity;
  final DateTime movementDate;
  final String? destination;
  final String? note;
}

class WarehouseResetAction extends WarehouseEvent {
  const WarehouseResetAction();
}

// --- STATES ---
class WarehouseState {
  const WarehouseState({
    this.materials = const [],
    this.materialsLoading = false,
    this.materialsError,
    this.total = 0,
    this.selectedMaterial,
    this.movements = const [],
    this.detailLoading = false,
    this.detailError,
    this.balance,
    this.actionLoading = false,
    this.actionSuccess = false,
    this.actionError,
  });

  final List<Material> materials;
  final bool materialsLoading;
  final String? materialsError;
  final int total;
  final Material? selectedMaterial;
  final List<StockMovement> movements;
  final bool detailLoading;
  final String? detailError;
  final MaterialBalance? balance;
  final bool actionLoading;
  final bool actionSuccess;
  final String? actionError;

  WarehouseState copyWith({
    List<Material>? materials,
    bool? materialsLoading,
    String? materialsError,
    int? total,
    Material? selectedMaterial,
    List<StockMovement>? movements,
    bool? detailLoading,
    String? detailError,
    MaterialBalance? balance,
    bool? actionLoading,
    bool? actionSuccess,
    String? actionError,
  }) {
    return WarehouseState(
      materials: materials ?? this.materials,
      materialsLoading: materialsLoading ?? this.materialsLoading,
      materialsError: materialsError ?? this.materialsError,
      total: total ?? this.total,
      selectedMaterial: selectedMaterial ?? this.selectedMaterial,
      movements: movements ?? this.movements,
      detailLoading: detailLoading ?? this.detailLoading,
      detailError: detailError ?? this.detailError,
      balance: balance ?? this.balance,
      actionLoading: actionLoading ?? this.actionLoading,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      actionError: actionError ?? this.actionError,
    );
  }
}

// --- BLOC ---
class WarehouseBloc extends Bloc<WarehouseEvent, WarehouseState> {
  WarehouseBloc({required WarehouseRepository warehouseRepository})
      : _warehouseRepository = warehouseRepository,
        super(const WarehouseState()) {
    on<WarehouseMaterialsLoadRequested>(_onLoadMaterials);
    on<WarehouseMaterialDetailRequested>(_onLoadDetail);
    on<WarehouseMaterialCreateRequested>(_onCreateMaterial);
    on<WarehouseMaterialUpdateRequested>(_onUpdateMaterial);
    on<WarehouseMaterialDeactivateRequested>(_onDeactivateMaterial);
    on<WarehouseMaterialActivateRequested>(_onActivateMaterial);
    on<WarehouseReceiptRequested>(_onReceipt);
    on<WarehouseIssuanceRequested>(_onIssuance);
    on<WarehouseResetAction>(_onResetAction);
  }

  final WarehouseRepository _warehouseRepository;

  Future<void> _onLoadMaterials(
    WarehouseMaterialsLoadRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(
      materialsLoading: state.materials.isEmpty,
      materialsError: null,
    ));
    try {
      final (materials, total) = await _warehouseRepository.fetchMaterials(
        isActive: event.isActive,
        category: event.category,
        search: event.search,
        limit: 100,
      );
      emit(state.copyWith(
        materials: materials,
        total: total,
        materialsLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        materialsLoading: false,
        materialsError: e.toString(),
      ));
    }
  }

  Future<void> _onLoadDetail(
    WarehouseMaterialDetailRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(
      detailLoading: true,
      detailError: null,
      selectedMaterial: event.material ?? state.selectedMaterial,
    ));
    try {
      final results = await Future.wait([
        _warehouseRepository.fetchMovements(event.materialId, limit: 50),
        _warehouseRepository.fetchBalance(event.materialId),
      ]);
      final (movements, _) = results[0] as (List<StockMovement>, int);
      final balance = results[1] as MaterialBalance;
      emit(state.copyWith(
        movements: movements,
        balance: balance,
        detailLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        detailLoading: false,
        detailError: e.toString(),
      ));
    }
  }

  Future<void> _onCreateMaterial(
    WarehouseMaterialCreateRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(actionLoading: true, actionError: null));
    try {
      await _warehouseRepository.createMaterial(
        code: event.code,
        name: event.name,
        category: event.category,
        unit: event.unit,
        minQuantity: event.minQuantity,
      );
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(const WarehouseMaterialsLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateMaterial(
    WarehouseMaterialUpdateRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(actionLoading: true, actionError: null));
    try {
      await _warehouseRepository.updateMaterial(
        id: event.id,
        name: event.name,
        category: event.category,
        minQuantity: event.minQuantity,
      );
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(const WarehouseMaterialsLoadRequested());
      if (state.selectedMaterial?.id == event.id) {
        add(WarehouseMaterialDetailRequested(
          materialId: event.id,
          material: state.selectedMaterial,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onDeactivateMaterial(
    WarehouseMaterialDeactivateRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(actionLoading: true, actionError: null));
    try {
      await _warehouseRepository.deactivateMaterial(event.id);
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(const WarehouseMaterialsLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onActivateMaterial(
    WarehouseMaterialActivateRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(actionLoading: true, actionError: null));
    try {
      await _warehouseRepository.activateMaterial(event.id);
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(const WarehouseMaterialsLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onReceipt(
    WarehouseReceiptRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(
      actionLoading: true,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _warehouseRepository.recordReceipt(
        materialId: event.materialId,
        quantity: event.quantity,
        movementDate: event.movementDate,
        supplierName: event.supplierName,
        note: event.note,
      );
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(WarehouseMaterialDetailRequested(
        materialId: event.materialId,
        material: state.selectedMaterial,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onIssuance(
    WarehouseIssuanceRequested event,
    Emitter<WarehouseState> emit,
  ) async {
    emit(state.copyWith(
      actionLoading: true,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _warehouseRepository.recordIssuance(
        materialId: event.materialId,
        quantity: event.quantity,
        movementDate: event.movementDate,
        destination: event.destination,
        note: event.note,
      );
      emit(state.copyWith(actionLoading: false, actionSuccess: true));
      add(WarehouseMaterialDetailRequested(
        materialId: event.materialId,
        material: state.selectedMaterial,
      ));
    } catch (e) {
      emit(state.copyWith(
        actionLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  void _onResetAction(
    WarehouseResetAction event,
    Emitter<WarehouseState> emit,
  ) {
    emit(state.copyWith(actionSuccess: false, actionError: null));
  }
}
