import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:texerp/core/network/network_info.dart';
import 'package:texerp/core/sync/sync_manager.dart';

class AutoSyncManager {
  AutoSyncManager({
    required NetworkInfo networkInfo,
    required SyncManager syncManager,
  })  : _networkInfo = networkInfo,
        _syncManager = syncManager;

  final NetworkInfo _networkInfo;
  final SyncManager _syncManager;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  void start() {
    _subscription = _networkInfo.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (!isConnected) {
        _wasOffline = true;
      } else if (_wasOffline) {
        _wasOffline = false;
        Future.delayed(const Duration(seconds: 2), () {
          _syncManager.syncPending();
        });
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
