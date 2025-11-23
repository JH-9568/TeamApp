import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../models/dashboard_models.dart';

class DashboardApi {
  DashboardApi({String? baseUrl, required String? token})
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

  Future<DashboardTeam> fetchTeamDetail(String teamId) async {
    final response = await http.get(
      _uri('/api/teams/$teamId'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final teamJson = body['team'] as Map<String, dynamic>;
    return DashboardTeam.fromJson(teamJson);
  }

  Future<List<DashboardActionItem>> fetchActionItems(String teamId) async {
    final response = await http.get(
      _uri('/api/teams/$teamId/action-items'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['actionItems'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DashboardActionItem.fromJson)
        .toList();
    return items;
  }

  Future<List<DashboardMeeting>> fetchMeetings(String teamId) async {
    final response = await http.get(
      _uri('/api/teams/$teamId/meetings'),
      headers: _headers,
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final meetings = (body['meetings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DashboardMeeting.fromJson)
        .toList();
    return meetings;
  }

  Future<DashboardActionItem> createActionItem({
    required String meetingId,
    required String type,
    required String assignee,
    required String content,
    String status = 'pending',
    DateTime? dueDate,
  }) async {
    final body = {
      'type': type.trim(),
      'assignee': assignee.trim(),
      'content': content.trim(),
      'status': status,
      if (dueDate != null)
        'dueDate': dueDate.toIso8601String().split('T').first,
    };
    final response = await http.post(
      _uri('/api/meetings/$meetingId/action-items'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _throwOnError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DashboardActionItem.fromJson(json);
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
