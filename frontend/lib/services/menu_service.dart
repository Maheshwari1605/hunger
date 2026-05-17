import '../models/menu_item.dart';
import 'api_client.dart';

class MenuService {
  final ApiClient _api;
  MenuService(this._api);

  Future<List<MenuItem>> list({String? category, String? q}) async {
    final res = await _api.get('/api/menu/items', query: {
      if (category != null) 'category': category,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res['items'] as List)
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuItem> create(Map<String, dynamic> data) async {
    final res = await _api.post('/api/menu/items', data);
    return MenuItem.fromJson(res['item'] as Map<String, dynamic>);
  }

  Future<MenuItem> update(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/api/menu/items/$id', data);
    return MenuItem.fromJson(res['item'] as Map<String, dynamic>);
  }

  Future<void> remove(String id) async {
    await _api.delete('/api/menu/items/$id');
  }

  Future<List<String>> categories() async {
    final res = await _api.get('/api/menu/categories');
    return (res['categories'] as List)
        .map((e) => (e as Map<String, dynamic>)['name'].toString())
        .toList();
  }
}
