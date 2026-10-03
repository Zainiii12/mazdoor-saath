import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Thrown when the backend answers with `{ok: false}` or a non-2xx status.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP wrapper around the Mazdoor Sathi backend.
///
/// Base URL comes from `--dart-define=API_BASE_URL=...` (defaults to the
/// Android-emulator loopback). Every request carries the Firebase ID token
/// of the signed-in user as `Authorization: Bearer <token>`.
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  final http.Client _http;

  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Unwrap the `{ok, data, error}` envelope or throw [ApiException].
  dynamic _unwrap(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid server response', res.statusCode);
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && body['ok'] == true) {
      return body['data'];
    }
    throw ApiException(
      body['error']?.toString() ?? 'Request failed',
      res.statusCode,
    );
  }

  Future<dynamic> get(String path) async {
    final res =
        await _http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _unwrap(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _unwrap(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await _http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _unwrap(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _http.delete(Uri.parse('$baseUrl$path'),
        headers: await _headers());
    return _unwrap(res);
  }

  void close() => _http.close();
}
