import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the active application locale.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('uz'));

  void setLocale(Locale locale) => emit(locale);
}
