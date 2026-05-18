import 'api_client.dart';

class TableService {
  final ApiClient _api;
  TableService(this._api);

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _api.get('/api/tables');
    return ((res['tables'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(String label, {int capacity = 4}) async {
    final res = await _api.post('/api/tables', {
      'label': label,
      'capacity': capacity,
    });
    return res['table'] as Map<String, dynamic>;
  }

  Future<void> remove(String id) => _api.delete('/api/tables/$id');
}
