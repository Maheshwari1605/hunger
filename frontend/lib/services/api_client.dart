import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  String _baseUrl = AppConfig.apiBaseUrl;
  String? _token;

  void setToken(String? token) => _token = token;
  void setBaseUrl(String url) => _baseUrl = url;

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      path: path,
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_u(path, query), headers: _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> post(String path, Object body) async {
    final res = await http.post(
      _u(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> put(String path, Object body) async {
    final res = await http.put(
      _u(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    final res = await http.patch(
      _u(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(_u(path), headers: _headers(json: false));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'Request failed';
    throw ApiException(res.statusCode, msg);
  }
}
