import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/team.dart';

class TeamApi {
  TeamApi({String? baseUrl, required String? token})
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

  Future<List<Team>> fetchTeams() async {
    final response = await http.get(_uri('/api/teams'), headers: _headers);
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final teams = (body['teams'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Team.fromJson)
        .toList();
    return teams;
  }

  Future<Team> createTeam(String name) async {
    final response = await http.post(
      _uri('/api/teams'),
      headers: _headers,
      body: jsonEncode({'name': name.trim()}),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final teamJson = body['team'] as Map<String, dynamic>;
    return Team.fromJson(teamJson);
  }

  Future<Team> joinTeam(String inviteCode) async {
    final response = await http.post(
      _uri('/api/teams/join'),
      headers: _headers,
      body: jsonEncode({'inviteCode': inviteCode.trim()}),
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final teamJson = body['team'] as Map<String, dynamic>;
    return Team.fromJson(teamJson);
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 400) {
      throw http.ClientException(
        '요청 실패 (${response.statusCode}): ${response.body}',
        response.request?.url,
      );
    }
  }
}
