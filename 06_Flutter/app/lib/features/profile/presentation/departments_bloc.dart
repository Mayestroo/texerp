import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';

abstract class DepartmentsEvent {
  const DepartmentsEvent();
}

class DepartmentsLoadRequested extends DepartmentsEvent {
  const DepartmentsLoadRequested({this.includeInactive = false});
  final bool includeInactive;
}

class DepartmentsCreateRequested extends DepartmentsEvent {
  const DepartmentsCreateRequested({
    required this.name,
    required this.code,
    required this.foremanId,
  });
  final String name;
  final String code;
  final String foremanId;
}

class DepartmentsUpdateRequested extends DepartmentsEvent {
  const DepartmentsUpdateRequested({
    required this.id,
    this.name,
    this.code,
    this.foremanId,
    this.isActive,
  });
  final String id;
  final String? name;
  final String? code;
  final String? foremanId;
  final bool? isActive;
}

class DepartmentsToggleStatusRequested extends DepartmentsEvent {
  const DepartmentsToggleStatusRequested({
    required this.id,
    required this.currentActive,
  });
  final String id;
  final bool currentActive;
}

class DepartmentsState {
  const DepartmentsState({
    this.departments = const [],
    this.foremen = const [],
    this.isLoading = false,
    this.error,
    this.actionInProgressId,
    this.actionSuccess = false,
    this.actionError,
  });

  final List<Department> departments;
  final List<UserProfile> foremen;
  final bool isLoading;
  final String? error;
  final String? actionInProgressId;
  final bool actionSuccess;
  final String? actionError;

  DepartmentsState copyWith({
    List<Department>? departments,
    List<UserProfile>? foremen,
    bool? isLoading,
    String? error,
    Object? actionInProgressId = const Object(),
    bool? actionSuccess,
    Object? actionError = const Object(),
  }) {
    return DepartmentsState(
      departments: departments ?? this.departments,
      foremen: foremen ?? this.foremen,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      actionInProgressId: actionInProgressId == const Object()
          ? this.actionInProgressId
          : (actionInProgressId as String?),
      actionSuccess: actionSuccess ?? this.actionSuccess,
      actionError: actionError == const Object()
          ? this.actionError
          : (actionError as String?),
    );
  }
}

class DepartmentsBloc extends Bloc<DepartmentsEvent, DepartmentsState> {
  DepartmentsBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const DepartmentsState()) {
    on<DepartmentsLoadRequested>(_onLoad);
    on<DepartmentsCreateRequested>(_onCreate);
    on<DepartmentsUpdateRequested>(_onUpdate);
    on<DepartmentsToggleStatusRequested>(_onToggleStatus);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onLoad(
    DepartmentsLoadRequested event,
    Emitter<DepartmentsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, actionSuccess: false));
    try {
      final results = await Future.wait([
        _profileRepository.fetchDepartments(includeInactive: event.includeInactive),
        _profileRepository.fetchUsers(role: 'FOREMAN', status: 'ACTIVE'),
      ]);
      final depts = results[0] as List<Department>;
      final (foremen, _) = results[1] as (List<UserProfile>, int);
      emit(state.copyWith(
        departments: depts,
        foremen: foremen,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onCreate(
    DepartmentsCreateRequested event,
    Emitter<DepartmentsState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: 'CREATE',
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final newDept = await _profileRepository.createDepartment(
        name: event.name,
        code: event.code,
        foremanId: event.foremanId,
      );
      final updatedList = List<Department>.from(state.departments)..insert(0, newDept);
      emit(state.copyWith(
        departments: updatedList,
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

  Future<void> _onUpdate(
    DepartmentsUpdateRequested event,
    Emitter<DepartmentsState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final updated = await _profileRepository.updateDepartment(
        id: event.id,
        name: event.name,
        code: event.code,
        foremanId: event.foremanId,
        isActive: event.isActive,
      );
      final updatedList = state.departments.map((d) {
        return d.id == event.id ? updated : d;
      }).toList();
      emit(state.copyWith(
        departments: updatedList,
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
    DepartmentsToggleStatusRequested event,
    Emitter<DepartmentsState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _profileRepository.updateDepartment(
        id: event.id,
        isActive: !event.currentActive,
      );
      final updatedList = state.departments.map((d) {
        if (d.id == event.id) {
          return Department(
            id: d.id,
            name: d.name,
            code: d.code,
            isActive: !event.currentActive,
            foremanName: d.foremanName,
            workerCount: d.workerCount,
          );
        }
        return d;
      }).toList();
      emit(state.copyWith(
        departments: updatedList,
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
