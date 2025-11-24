import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/common/models/user.dart';
import 'package:frontend/core/errors/unauthorized_exception.dart';

class MyPageApi {
  MyPageApi({String? baseUrl, required String? token})
    : _baseUrl = _normalizeBaseUrl(baseUrl ?? _loadBaseUrl()),
      _token = token;

  final String _baseUrl;
  final String? _token;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> get _headers {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw http.ClientException('로그인이 필요합니다.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _loadBaseUrl() {
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

  Future<User> fetchProfile() async {
    final response = await http.get(_uri('/api/users/me'), headers: _headers);
    debugPrint('[MyPageApi] GET /api/users/me -> ${response.statusCode}');
    _throwOnError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(json);
  }

  Future<User> updateProfile({String? name, String? avatar}) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (avatar != null) payload['avatar'] = avatar;
    final response = await http.patch(
      _uri('/api/users/me'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    debugPrint('[MyPageApi] PATCH /api/users/me -> ${response.statusCode}');
    _throwOnError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(json);
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode >= 400) {
      throw http.ClientException(
        '요청 실패 (${response.statusCode}): ${response.body}',
        response.request?.url,
      );
    }
  }
}
