import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight on-device cache:
///  - Last-known menu items (JSON list)
///  - Pending orders queue (JSON list of order payloads waiting to sync)
class LocalStore {
  static const _kMenu = 'cached_menu_items_v1';
  static const _kQueue = 'pending_orders_v1';

  final SharedPreferences _prefs;
  LocalStore._(this._prefs);

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  // ---- Menu cache ---------------------------------------------------------

  Future<void> saveMenu(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_kMenu, jsonEncode(items));
  }

  List<Map<String, dynamic>>? readMenu() {
    final raw = _prefs.getString(_kMenu);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded.cast<Map<String, dynamic>>();
  }

  // ---- Pending order queue -----------------------------------------------

  List<Map<String, dynamic>> readQueue() {
    final raw = _prefs.getString(_kQueue);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeQueue(List<Map<String, dynamic>> queue) async {
    await _prefs.setString(_kQueue, jsonEncode(queue));
  }

  Future<void> enqueueOrder(Map<String, dynamic> payload) async {
    final q = readQueue()..add(payload);
    await writeQueue(q);
  }

  Future<void> removeFromQueue(String localId) async {
    final q = readQueue()..removeWhere((o) => o['localId'] == localId);
    await writeQueue(q);
  }

  int queueCount() => readQueue().length;
}
