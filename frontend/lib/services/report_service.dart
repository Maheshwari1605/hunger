import 'package:intl/intl.dart';
import 'api_client.dart';

class ReportService {
  final ApiClient _api;
  ReportService(this._api);

  Future<Map<String, dynamic>> daily([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final res = await _api.get('/api/reports/daily', query: {
      'date': DateFormat('yyyy-MM-dd').format(d),
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> monthly([DateTime? month]) async {
    final m = month ?? DateTime.now();
    final res = await _api.get('/api/reports/monthly', query: {
      'month': DateFormat('yyyy-MM').format(m),
    });
    return res as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> bestSelling({
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    final res = await _api.get('/api/reports/best-selling', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'limit': limit,
    });
    return ((res as Map<String, dynamic>)['items'] as List)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> paymentMix({DateTime? from, DateTime? to}) async {
    final res = await _api.get('/api/reports/payment-mix', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    });
    return ((res as Map<String, dynamic>)['mix'] as List)
        .cast<Map<String, dynamic>>();
  }
}
