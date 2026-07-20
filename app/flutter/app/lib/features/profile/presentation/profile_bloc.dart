import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested({required this.userId});

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileLogoutRequested extends ProfileEvent {
  const ProfileLogoutRequested();
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.user});

  final UserProfile user;

  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  const ProfileFailure({required this.error, required this.code});

  final String error;
  final String code;

  @override
  List<Object?> get props => [error, code];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required ProfileRepository profileRepository,
    required AuthRepository authRepository,
    required VoidCallback onLogout,
  })  : _profileRepository = profileRepository,
        _authRepository = authRepository,
        _onLogout = onLogout,
        super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileLogoutRequested>(_onLogoutRequested);
  }

  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;
  final VoidCallback _onLogout;

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final user = await _profileRepository.getProfile(event.userId);
      emit(ProfileLoaded(user: user));
    } on NetworkException catch (e) {
      emit(ProfileFailure(error: e.message, code: e.code));
    } catch (e) {
      emit(ProfileFailure(error: e.toString(), code: 'UNKNOWN_ERROR'));
    }
  }

  Future<void> _onLogoutRequested(
    ProfileLogoutRequested event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _authRepository.logout();
    } on NetworkException catch (e) {
      // Still force local logout even if the server call fails.
      debugPrint('Logout server call failed: ${e.message}');
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
    _onLogout();
  }
}
