import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Reactive online/offline flag. `online` means at least one network interface
/// is up. It does NOT guarantee that our API is reachable — only that the
/// device has some connection.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get online => _online;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _online = _isOnline(initial);
    } catch (_) {
      _online = true; // optimistic fallback
    }
    notifyListeners();

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _online;
      _online = _isOnline(results);
      if (_online != wasOnline) notifyListeners();
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
