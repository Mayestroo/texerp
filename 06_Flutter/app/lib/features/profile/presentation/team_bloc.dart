import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';

// --- EVENTS ---
abstract class TeamEvent {
  const TeamEvent();
}

class TeamLoadRequested extends TeamEvent {
  const TeamLoadRequested();
}

// --- STATES ---
class TeamState {
  const TeamState({
    this.workers = const [],
    this.isLoading = false,
    this.error,
  });

  final List<UserProfile> workers;
  final bool isLoading;
  final String? error;

  TeamState copyWith({
    List<UserProfile>? workers,
    bool? isLoading,
    String? error,
  }) {
    return TeamState(
      workers: workers ?? this.workers,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// --- BLOC ---
class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const TeamState()) {
    on<TeamLoadRequested>(_onLoadTeam);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onLoadTeam(
    TeamLoadRequested event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final workers = await _profileRepository.fetchMyWorkers();
      emit(state.copyWith(
        workers: workers,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
