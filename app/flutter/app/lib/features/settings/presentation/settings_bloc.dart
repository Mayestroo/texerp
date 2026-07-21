import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/features/settings/data/settings_models.dart';
import 'package:texerp/features/settings/data/settings_repository.dart';

// ---------------------------------------------------------------------------
// DTO
// ---------------------------------------------------------------------------

class SettingsUpdateDto {
  const SettingsUpdateDto({
    this.backDateWindowDays,
    this.suspiciousQuantityMultiplier,
    this.payrollMinPay,
    this.duplicateWindowMinutes,
  });

  final int? backDateWindowDays;
  final int? suspiciousQuantityMultiplier;
  final int? payrollMinPay;
  final int? duplicateWindowMinutes;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsUpdateRequested extends SettingsEvent {
  const SettingsUpdateRequested({required this.dto});

  final SettingsUpdateDto dto;

  @override
  List<Object?> get props => [dto];
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded({required this.settings});

  final TenantSettings settings;

  @override
  List<Object?> get props => [settings];
}

class SettingsUpdating extends SettingsState {
  const SettingsUpdating();
}

class SettingsUpdated extends SettingsState {
  const SettingsUpdated({required this.settings});

  final TenantSettings settings;

  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  const SettingsError({required this.message, this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository,
        super(const SettingsInitial()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsUpdateRequested>(_onUpdateRequested);
  }

  final SettingsRepository _settingsRepository;

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    try {
      final settings = await _settingsRepository.fetchSettings();
      emit(SettingsLoaded(settings: settings));
    } on NetworkException catch (e) {
      emit(SettingsError(message: e.message, code: e.code));
    } catch (e) {
      emit(SettingsError(message: e.toString(), code: 'UNKNOWN_ERROR'));
    }
  }

  Future<void> _onUpdateRequested(
    SettingsUpdateRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsUpdating());
    try {
      final settings = await _settingsRepository.updateSettings(
        backDateWindowDays: event.dto.backDateWindowDays,
        suspiciousQuantityMultiplier: event.dto.suspiciousQuantityMultiplier,
        payrollMinPay: event.dto.payrollMinPay,
        duplicateWindowMinutes: event.dto.duplicateWindowMinutes,
      );
      emit(SettingsUpdated(settings: settings));
      emit(SettingsLoaded(settings: settings));
    } on NetworkException catch (e) {
      emit(SettingsError(message: e.message, code: e.code));
    } catch (e) {
      emit(SettingsError(message: e.toString(), code: 'UNKNOWN_ERROR'));
    }
  }
}
