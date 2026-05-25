import 'package:flutter/foundation.dart';
import 'api_client.dart';

class OutletSettings {
  final String outletId;
  final double taxRate;
  final String currency;
  final String cafeName;
  final String address;
  final String phone;
  final String gstNumber;
  final String receiptFooter;

  OutletSettings({
    required this.outletId,
    required this.taxRate,
    required this.currency,
    required this.cafeName,
    required this.address,
    required this.phone,
    required this.gstNumber,
    required this.receiptFooter,
  });

  factory OutletSettings.fromJson(Map<String, dynamic> j) => OutletSettings(
        outletId: (j['outletId'] ?? 'default') as String,
        taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] ?? '₹') as String,
        cafeName: (j['cafeName'] ?? 'Hunger Cafe') as String,
        address: (j['address'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        gstNumber: (j['gstNumber'] ?? '') as String,
        receiptFooter:
            (j['receiptFooter'] ?? 'Thank you — visit again!') as String,
      );
}

class SettingsService extends ChangeNotifier {
  final ApiClient _api;
  OutletSettings? _settings;

  SettingsService(this._api);

  OutletSettings? get settings => _settings;
  // Tax-free POS — always 0 regardless of what's stored.
  double get taxRate => 0;

  Future<void> load() async {
    try {
      final res = await _api.get('/api/settings');
      _settings =
          OutletSettings.fromJson(res['settings'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      // Stay with defaults — settings are optional for runtime.
    }
  }

  Future<void> update(Map<String, dynamic> patch) async {
    final res = await _api.put('/api/settings', patch);
    _settings = OutletSettings.fromJson(res['settings'] as Map<String, dynamic>);
    notifyListeners();
  }
}
