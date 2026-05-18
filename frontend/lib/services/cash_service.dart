import 'package:flutter/foundation.dart';
import 'api_client.dart';

class CashService extends ChangeNotifier {
  final ApiClient _api;
  Map<String, dynamic>? _current;

  CashService(this._api);

  Map<String, dynamic>? get current => _current;
  bool get hasOpenSession =>
      _current != null && _current!['session'] != null;

  Future<void> refresh() async {
    try {
      _current = await _api.get('/api/cash/current') as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {
      _current = null;
      notifyListeners();
    }
  }

  Future<void> open(double openingBalance) async {
    await _api.post('/api/cash/open', {'openingBalance': openingBalance});
    await refresh();
  }

  Future<void> close(double closingBalance) async {
    await _api.post('/api/cash/close', {'closingBalance': closingBalance});
    await refresh();
  }

  Future<void> addEntry({
    required String type, // expense | withdrawal | topup
    required double amount,
    String note = '',
  }) async {
    await _api.post('/api/cash/entry', {
      'type': type,
      'amount': amount,
      'note': note,
    });
    await refresh();
  }
}
