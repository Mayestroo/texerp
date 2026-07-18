import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/core/network/token_provider.dart';
import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.phone, required this.pin});

  final String phone;
  final String pin;

  @override
  List<Object?> get props => [phone, pin];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}

class AuthRefreshRequested extends AuthEvent {
  const AuthRefreshRequested();
}

class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

class AuthAccessTokenRefreshed extends AuthEvent {
  const AuthAccessTokenRefreshed({required this.accessToken});

  final String accessToken;

  @override
  List<Object?> get props => [accessToken];
}

class AuthUnlockRequested extends AuthEvent {
  const AuthUnlockRequested();
}

class AuthPinUpdated extends AuthEvent {
  const AuthPinUpdated({required this.newPin});

  final String newPin;

  @override
  List<Object?> get props => [newPin];
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

abstract class AuthState extends Equatable {
  const AuthState({this.accessToken, this.user, this.currentPin, this.isLocked = false});

  final String? accessToken;
  final UserProfile? user;
  final String? currentPin;
  final bool isLocked;

  @override
  List<Object?> get props => [accessToken, user, currentPin, isLocked];
}

class AuthInitial extends AuthState {
  const AuthInitial() : super();
}

class AuthLoading extends AuthState {
  const AuthLoading() : super();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required super.user,
    required super.accessToken,
    super.currentPin,
    super.isLocked = false,
  });

  @override
  UserProfile get user => super.user!;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated() : super();
}

class AuthFailure extends AuthState {
  const AuthFailure({required this.error}) : super();

  final NetworkException error;

  @override
  List<Object?> get props => [error];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required SecureStorage secureStorage,
    required TokenProvider tokenProvider,
  })  : _authRepository = authRepository,
        _secureStorage = secureStorage,
        _tokenProvider = tokenProvider,
        super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthRefreshRequested>(_onRefreshRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthAccessTokenRefreshed>(_onAccessTokenRefreshed);
    on<AuthUnlockRequested>(_onUnlockRequested);
    on<AuthPinUpdated>(_onPinUpdated);

    add(const AuthCheckStatus());
  }

  final AuthRepository _authRepository;
  final SecureStorage _secureStorage;
  final TokenProvider _tokenProvider;

  @override
  void onChange(Change<AuthState> change) {
    _tokenProvider.accessToken = change.nextState.accessToken;
    super.onChange(change);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final (user, accessToken) = await _authRepository.login(
        phone: event.phone,
        pin: event.pin,
      );
      emit(
        AuthAuthenticated(
          user: user,
          accessToken: accessToken,
          currentPin: event.pin,
        ),
      );
    } on NetworkException catch (e) {
      emit(AuthFailure(error: e));
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(
        AuthFailure(
          error: NetworkException(code: 'UNKNOWN_ERROR', message: e.toString()),
        ),
      );
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _secureStorage.clearTokens();
    _tokenProvider.accessToken = null;
    emit(const AuthUnauthenticated());
  }

  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final refreshToken = await _secureStorage.loadRefreshToken();
    if (refreshToken == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final accessToken = await _authRepository.refreshToken(refreshToken);
      final parts = accessToken.split('.');
      final payload = String.fromCharCodes(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final userId = decoded['sub'] as String;
      final user = await _authRepository.getProfile(userId);
      final usePinLock = await _secureStorage.getUsePinLock();
      emit(
        AuthAuthenticated(
          user: user,
          accessToken: accessToken,
          isLocked: usePinLock,
        ),
      );
    } on NetworkException catch (e) {
      if (e.code == 'NETWORK_ERROR') {
        emit(AuthFailure(error: e));
        emit(const AuthUnauthenticated());
      } else {
        await _secureStorage.clearTokens();
        _tokenProvider.accessToken = null;
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      await _secureStorage.clearTokens();
      _tokenProvider.accessToken = null;
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshRequested(
    AuthRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final refreshToken = await _secureStorage.loadRefreshToken();
    if (refreshToken == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final accessToken = await _authRepository.refreshToken(refreshToken);
      final parts = accessToken.split('.');
      final payload = String.fromCharCodes(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final userId = decoded['sub'] as String;
      final user = state.user ?? await _authRepository.getProfile(userId);
      emit(
        AuthAuthenticated(
          user: user,
          accessToken: accessToken,
          isLocked: state.isLocked,
        ),
      );
    } on NetworkException catch (e) {
      if (e.code == 'NETWORK_ERROR') {
        emit(AuthFailure(error: e));
        emit(const AuthUnauthenticated());
      } else {
        await _secureStorage.clearTokens();
        _tokenProvider.accessToken = null;
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      await _secureStorage.clearTokens();
      _tokenProvider.accessToken = null;
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    await _secureStorage.clearTokens();
    _tokenProvider.accessToken = null;
    emit(const AuthUnauthenticated());
  }

  void _onAccessTokenRefreshed(
    AuthAccessTokenRefreshed event,
    Emitter<AuthState> emit,
  ) {
    final current = state.user;
    if (current != null) {
      emit(
        AuthAuthenticated(
          user: current,
          accessToken: event.accessToken,
          currentPin: state.currentPin,
          isLocked: state.isLocked,
        ),
      );
    }
  }

  void _onUnlockRequested(
    AuthUnlockRequested event,
    Emitter<AuthState> emit,
  ) {
    final current = state.user;
    if (current != null && state is AuthAuthenticated) {
      emit(
        AuthAuthenticated(
          user: current,
          accessToken: state.accessToken,
          currentPin: state.currentPin,
          isLocked: false,
        ),
      );
    }
  }

  void _onPinUpdated(
    AuthPinUpdated event,
    Emitter<AuthState> emit,
  ) {
    final current = state.user;
    if (current != null && state is AuthAuthenticated) {
      emit(
        AuthAuthenticated(
          user: current,
          accessToken: state.accessToken,
          currentPin: event.newPin,
          isLocked: state.isLocked,
        ),
      );
    }
  }
}
