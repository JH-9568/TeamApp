import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../models/meeting_models.dart';

class MeetingApi {
  MeetingApi({String? baseUrl, required String? token})
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

  Future<MeetingDetail> fetchMeeting(String meetingId) async {
    final response = await http.get(_uri('/api/meetings/$meetingId'), headers: _headers);
    debugPrint('[MeetingApi] GET /api/meetings/$meetingId -> ${response.statusCode}');
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MeetingDetail.fromJson(body['meeting'] as Map<String, dynamic>);
  }

  Future<List<MeetingAttendee>> fetchAttendees(String meetingId) async {
    final response = await http.get(
      _uri('/api/meetings/$meetingId/attendees'),
      headers: _headers,
    );
    debugPrint('[MeetingApi] GET /api/meetings/$meetingId/attendees -> ${response.statusCode}');
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final attendees = body['attendees'] as List<dynamic>? ?? [];
    return attendees
        .map((item) => MeetingAttendee.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> requestSummary(String meetingId) async {
    final response = await http.post(
      _uri('/api/ai/summarize'),
      headers: _headers,
      body: jsonEncode({'meetingId': meetingId}),
    );
    debugPrint('[MeetingApi] POST /api/ai/summarize -> ${response.statusCode}');
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['summary'] as String? ?? '';
  }

  Future<List<MeetingActionItem>> requestActionItems(String meetingId) async {
    final response = await http.post(
      _uri('/api/ai/extract-action-items'),
      headers: _headers,
      body: jsonEncode({'meetingId': meetingId}),
    );
    debugPrint(
      '[MeetingApi] POST /api/ai/extract-action-items -> ${response.statusCode}',
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['actionItems'] as List<dynamic>? ?? [];
    return items
        .map((item) => MeetingActionItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MeetingActionItem> createActionItem(
    String meetingId,
    ActionItemInput input,
  ) async {
    final response = await http.post(
      _uri('/api/meetings/$meetingId/action-items'),
      headers: _headers,
      body: jsonEncode(input.toJson()),
    );
    debugPrint(
      '[MeetingApi] POST /api/meetings/$meetingId/action-items -> ${response.statusCode}',
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MeetingActionItem.fromJson(body);
  }

  Future<void> endMeeting(String meetingId) async {
    final response = await http.patch(
      _uri('/api/meetings/$meetingId'),
      headers: _headers,
      body: jsonEncode({'status': 'completed'}),
    );
    debugPrint('[MeetingApi] PATCH /api/meetings/$meetingId -> ${response.statusCode}');
    _throwOnError(response);
  }

  WebSocketChannel connectToMeeting(String meetingId) {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const UnauthorizedException();
    }
    final httpUri = Uri.parse(_baseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: '/ws/meetings/$meetingId',
      queryParameters: {'token': token},
    );
    return WebSocketChannel.connect(wsUri);
  }

  Future<void> registerAttendee(
    String meetingId, {
    String? userId,
    String? guestName,
  }) async {
    final payload = <String, dynamic>{};
    if (userId != null) {
      payload['userId'] = userId;
    } else if (guestName != null && guestName.isNotEmpty) {
      payload['guestName'] = guestName;
    }
    final response = await http.post(
      _uri('/api/meetings/$meetingId/attendees'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    debugPrint(
      '[MeetingApi] POST /api/meetings/$meetingId/attendees -> ${response.statusCode}',
    );
    _throwOnError(response);
  }

  Future<TranscriptSegment> addTranscript({
    required String meetingId,
    required String speaker,
    required String text,
    required String timestamp,
  }) async {
    final response = await http.post(
      _uri('/api/meetings/$meetingId/transcript'),
      headers: _headers,
      body: jsonEncode(
        {
          'speaker': speaker,
          'text': text,
          'timestamp': timestamp,
        },
      ),
    );
    debugPrint(
      '[MeetingApi] POST /api/meetings/$meetingId/transcript -> ${response.statusCode}',
    );
    _throwOnError(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return TranscriptSegment.fromJson(
      body['transcript'] as Map<String, dynamic>,
    );
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
