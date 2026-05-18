import 'api_client.dart';

class CustomerService {
  final ApiClient _api;
  CustomerService(this._api);

  Future<List<Map<String, dynamic>>> list({String? q}) async {
    final res = await _api.get('/api/customers',
        query: {if (q != null && q.isNotEmpty) 'q': q});
    return ((res['customers'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> lookup(String phone) async {
    try {
      final res = await _api.get('/api/customers/lookup', query: {'phone': phone});
      return res['customer'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await _api.post('/api/customers', data);
    return res['customer'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/api/customers/$id', data);
    return res['customer'] as Map<String, dynamic>;
  }

  Future<void> remove(String id) => _api.delete('/api/customers/$id');
}
