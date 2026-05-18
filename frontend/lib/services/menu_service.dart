import '../models/menu_item.dart';
import 'api_client.dart';
import 'local_store.dart';

class MenuService {
  final ApiClient _api;
  final LocalStore _store;
  MenuService(this._api, this._store);

  /// Returns the menu, preferring fresh data from the API. If the API call
  /// fails (e.g. offline), returns the last cached menu — or an empty list
  /// if we've never been online.
  Future<List<MenuItem>> list({String? category, String? q}) async {
    try {
      final res = await _api.get('/api/menu/items', query: {
        if (category != null) 'category': category,
        if (q != null && q.isNotEmpty) 'q': q,
      });
      final raw = (res['items'] as List).cast<Map<String, dynamic>>();
      // Cache only unfiltered queries so we have the full menu offline.
      if (category == null && (q == null || q.isEmpty)) {
        await _store.saveMenu(raw);
      }
      return raw.map(MenuItem.fromJson).toList();
    } catch (_) {
      final cached = _store.readMenu();
      if (cached == null) rethrow;
      final items = cached.map(MenuItem.fromJson).toList();
      // Apply the same filters locally so the caller's contract still holds.
      return items.where((it) {
        if (category != null && it.category != category) return false;
        if (q != null && q.isNotEmpty &&
            !it.name.toLowerCase().contains(q.toLowerCase())) {
          return false;
        }
        return true;
      }).toList();
    }
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
