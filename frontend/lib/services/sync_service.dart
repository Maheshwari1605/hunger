import 'dart:async';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'connectivity_service.dart';
import 'local_store.dart';

/// Watches connectivity and flushes the offline order queue when online.
///
/// Strategy:
///  - On going online → attempt to flush.
///  - Periodically while online → attempt to flush (covers cases where the
///    network is up but the API was down when we last tried).
///  - Each order is POSTed; on success it's removed from the queue, on
///    failure it stays for the next attempt.
class SyncService extends ChangeNotifier {
  final ApiClient _api;
  final LocalStore _store;
  final ConnectivityService _conn;

  Timer? _ticker;
  bool _running = false;
  String? _lastError;

  SyncService(this._api, this._store, this._conn) {
    _conn.addListener(_onConnChanged);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_conn.online) flush();
    });
    // Initial pass: maybe we have leftovers from a previous session.
    if (_conn.online) flush();
  }

  int get pendingCount => _store.queueCount();
  bool get isRunning => _running;
  String? get lastError => _lastError;

  void _onConnChanged() {
    if (_conn.online) flush();
  }

  Future<void> flush() async {
    if (_running) return;
    final queue = _store.readQueue();
    if (queue.isEmpty) return;

    _running = true;
    _lastError = null;
    notifyListeners();

    for (final entry in List.of(queue)) {
      final payload = entry['payload'] as Map<String, dynamic>;
      final localId = entry['localId'] as String;
      try {
        await _api.post('/api/orders', payload);
        await _store.removeFromQueue(localId);
        notifyListeners();
      } catch (e) {
        _lastError = e.toString();
        notifyListeners();
        // Stop the loop — if one failed, the next will likely fail too.
        break;
      }
    }

    _running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _conn.removeListener(_onConnChanged);
    super.dispose();
  }
}
