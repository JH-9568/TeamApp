import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

class AuthApi {
  AuthApi({String? baseUrl}) : _baseUrl = baseUrl ?? _loadBaseUrl();

  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  static String _loadBaseUrl() {
    final raw = _readFromEnv();
    return _normalizeBaseUrl(raw);
  }

  static String _readFromEnv() {
    try {
      return dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000';
    } on NotInitializedError {
      return 'http://127.0.0.1:8000';
    }
  }

  static String _normalizeBaseUrl(String baseUrl) {
    if (kIsWeb) return baseUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final uri = Uri.tryParse(baseUrl);
      if (uri != null &&
          (uri.host == '127.0.0.1' || uri.host.toLowerCase() == 'localhost')) {
        return uri.replace(host: '10.0.2.2').toString();
      }
    }
    return baseUrl;
  }

  Future<AuthSession> login(String email, String password) async {
    final uri = _uri('/api/auth/login');
    debugPrint('[AuthApi] POST $uri (login) email=$email');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    debugPrint(
      '[AuthApi] login response ${response.statusCode}: ${response.body}',
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> signup(String name, String email, String password) async {
    final uri = _uri('/api/auth/register');
    debugPrint('[AuthApi] POST $uri (signup) email=$email name=$name');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );
    debugPrint(
      '[AuthApi] signup response ${response.statusCode}: ${response.body}',
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(body);
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 400) {
      debugPrint(
        '[AuthApi] Request error (${response.statusCode}): ${response.body}',
      );
      throw http.ClientException(
        'Request failed (${response.statusCode}): ${response.body}',
        response.request?.url,
      );
    }
  }
}
