import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';

// --- EVENTS ---
abstract class WorkersEvent {
  const WorkersEvent();
}

class WorkersLoadRequested extends WorkersEvent {
  const WorkersLoadRequested({this.role, this.status = 'ACTIVE', this.search});
  final String? role;
  final String status;
  final String? search;
}

class WorkersCreateRequested extends WorkersEvent {
  const WorkersCreateRequested({
    required this.fullName,
    required this.phone,
    required this.workerCode,
    required this.role,
    required this.initialPin,
  });
  final String fullName;
  final String phone;
  final String workerCode;
  final String role;
  final String initialPin;
}

class WorkersUpdateRequested extends WorkersEvent {
  const WorkersUpdateRequested({
    required this.id,
    required this.fullName,
  });
  final String id;
  final String fullName;
}

class WorkersToggleStatusRequested extends WorkersEvent {
  const WorkersToggleStatusRequested({
    required this.id,
    required this.currentActive,
  });
  final String id;
  final bool currentActive;
}

class WorkersLoadAssistanceDataRequested extends WorkersEvent {
  const WorkersLoadAssistanceDataRequested();
}

class WorkersAssignForemanRequested extends WorkersEvent {
  const WorkersAssignForemanRequested({
    required this.workerId,
    required this.foremanId,
    required this.departmentId,
  });
  final String workerId;
  final String foremanId;
  final String departmentId;
}

class WorkersUnassignForemanRequested extends WorkersEvent {
  const WorkersUnassignForemanRequested({required this.workerId});
  final String workerId;
}

// --- STATES ---
class WorkersState {
  const WorkersState({
    this.users = const [],
    this.departments = const [],
    this.foremen = const [],
    this.isLoading = false,
    this.isAssistanceLoading = false,
    this.error,
    this.role,
    this.status = 'ACTIVE',
    this.actionInProgressId,
    this.actionSuccess = false,
    this.actionError,
  });

  final List<UserProfile> users;
  final List<Department> departments;
  final List<UserProfile> foremen;
  final bool isLoading;
  final bool isAssistanceLoading;
  final String? error;
  final String? role;
  final String status;
  final String? actionInProgressId;
  final bool actionSuccess;
  final String? actionError;

  WorkersState copyWith({
    List<UserProfile>? users,
    List<Department>? departments,
    List<UserProfile>? foremen,
    bool? isLoading,
    bool? isAssistanceLoading,
    String? error,
    String? role,
    String? status,
    Object? actionInProgressId = const Object(),
    bool? actionSuccess,
    Object? actionError = const Object(),
  }) {
    return WorkersState(
      users: users ?? this.users,
      departments: departments ?? this.departments,
      foremen: foremen ?? this.foremen,
      isLoading: isLoading ?? this.isLoading,
      isAssistanceLoading: isAssistanceLoading ?? this.isAssistanceLoading,
      error: error ?? this.error,
      role: role ?? this.role,
      status: status ?? this.status,
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

// --- BLOC ---
class WorkersBloc extends Bloc<WorkersEvent, WorkersState> {
  WorkersBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const WorkersState()) {
    on<WorkersLoadRequested>(_onLoadUsers);
    on<WorkersCreateRequested>(_onCreateUser);
    on<WorkersUpdateRequested>(_onUpdateUser);
    on<WorkersToggleStatusRequested>(_onToggleStatus);
    on<WorkersLoadAssistanceDataRequested>(_onLoadAssistanceData);
    on<WorkersAssignForemanRequested>(_onAssignForeman);
    on<WorkersUnassignForemanRequested>(_onUnassignForeman);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onLoadUsers(
    WorkersLoadRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      error: null,
      role: event.role,
      status: event.status,
      actionSuccess: false,
    ));
    try {
      final (users, _) = await _profileRepository.fetchUsers(
        role: event.role,
        status: event.status,
        search: event.search,
      );
      emit(state.copyWith(
        users: users,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateUser(
    WorkersCreateRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: 'CREATE',
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final newUser = await _profileRepository.createUser(
        fullName: event.fullName,
        phone: event.phone,
        workerCode: event.workerCode,
        role: event.role,
        initialPin: event.initialPin,
      );

      final updatedList = List<UserProfile>.from(state.users);
      // Insert if role matches filter
      if (state.role == null || state.role == event.role) {
        if (state.status == 'ACTIVE' || state.status == 'ALL') {
          updatedList.insert(0, newUser);
        }
      }

      emit(state.copyWith(
        users: updatedList,
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

  Future<void> _onUpdateUser(
    WorkersUpdateRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      final updatedUser = await _profileRepository.updateUser(
        id: event.id,
        fullName: event.fullName,
      );

      final updatedList = state.users.map((u) {
        return u.id == event.id ? updatedUser : u;
      }).toList();

      emit(state.copyWith(
        users: updatedList,
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
    WorkersToggleStatusRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.id,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      if (event.currentActive) {
        await _profileRepository.deactivateUser(event.id);
      } else {
        await _profileRepository.reactivateUser(event.id);
      }

      final updatedList = List<UserProfile>.from(state.users);
      if (state.status != 'ALL') {
        updatedList.removeWhere((u) => u.id == event.id);
      } else {
        final index = updatedList.indexWhere((u) => u.id == event.id);
        if (index != -1) {
          final old = updatedList[index];
          updatedList[index] = UserProfile(
            id: old.id,
            fullName: old.fullName,
            phone: old.phone,
            workerCode: old.workerCode,
            role: old.role,
            status: event.currentActive ? 'DEACTIVATED' : 'ACTIVE',
            avatarUrl: old.avatarUrl,
            department: old.department,
            foreman: old.foreman,
          );
        }
      }

      emit(state.copyWith(
        users: updatedList,
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

  Future<void> _onLoadAssistanceData(
    WorkersLoadAssistanceDataRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(isAssistanceLoading: true, actionError: null));
    try {
      final depts = await _profileRepository.fetchDepartments();
      print('DEBUG WorkersBloc: Loaded departments: ${depts.map((d) => "${d.name} (${d.id})").toList()}');
      // Load foremen list (ACTIVE status only)
      final (foremenList, _) = await _profileRepository.fetchUsers(role: 'FOREMAN', status: 'ACTIVE');

      emit(state.copyWith(
        departments: depts,
        foremen: foremenList,
        isAssistanceLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isAssistanceLoading: false,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> _onAssignForeman(
    WorkersAssignForemanRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.workerId,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _profileRepository.assignForeman(
        workerId: event.workerId,
        foremanId: event.foremanId,
        departmentId: event.departmentId,
      );

      // Re-load current page to sync all assignments details
      final (users, _) = await _profileRepository.fetchUsers(
        role: state.role,
        status: state.status,
      );

      emit(state.copyWith(
        users: users,
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

  Future<void> _onUnassignForeman(
    WorkersUnassignForemanRequested event,
    Emitter<WorkersState> emit,
  ) async {
    emit(state.copyWith(
      actionInProgressId: event.workerId,
      actionError: null,
      actionSuccess: false,
    ));
    try {
      await _profileRepository.unassignForeman(workerId: event.workerId);

      // Re-load list to sync
      final (users, _) = await _profileRepository.fetchUsers(
        role: state.role,
        status: state.status,
      );

      emit(state.copyWith(
        users: users,
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
