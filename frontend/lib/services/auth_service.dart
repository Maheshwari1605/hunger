import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _api;
  AppUser? _user;
  String? _token;

  AuthService(this._api);

  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    if (t == null) return;
    _api.setToken(t);
    try {
      final res = await _api.get('/api/auth/me');
      _user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
      _token = t;
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    _token = res['token'] as String;
    _user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    _api.setToken(_token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
