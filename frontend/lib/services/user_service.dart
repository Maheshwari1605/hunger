import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Lightweight view of a backend User record (no password hash).
class StaffUser {
  final String id;
  final String name;
  final String email;
  final String role; // admin | cashier | kitchen
  final bool active;

  StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
        id: (j['id'] ?? j['_id']).toString(),
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        role: (j['role'] ?? 'cashier') as String,
        active: (j['active'] ?? true) as bool,
      );
}

/// Wraps the admin user-management endpoints and the
/// self-serve change-password endpoint.
class UserService extends ChangeNotifier {
  final ApiClient _api;
  UserService(this._api);

  Future<List<StaffUser>> list() async {
    final res = await _api.get('/api/auth/users');
    final raw = (res['users'] as List?) ?? const [];
    return raw
        .map((e) => StaffUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffUser> create({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await _api.post('/api/auth/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    return StaffUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<StaffUser> update(
    String id, {
    String? name,
    String? role,
    bool? active,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = role;
    if (active != null) body['active'] = active;
    if (newPassword != null && newPassword.isNotEmpty) {
      body['newPassword'] = newPassword;
    }
    final res = await _api.put('/api/auth/users/$id', body);
    return StaffUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
