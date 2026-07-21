import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:texerp/core/network/network_info.dart';

class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._networkInfo) : super(true) {
    _init();
  }

  final NetworkInfo _networkInfo;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    final connected = await _networkInfo.isConnected;
    emit(connected);
    _subscription = _networkInfo.onConnectivityChanged.listen((results) {
      emit(!results.contains(ConnectivityResult.none));
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
