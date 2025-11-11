import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class BackendClient {
  BackendClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<String> getHealth() async {
    final response = await http.get(_uri('/api/health'));
    _throwOnError(response);
    return response.body;
  }

  Future<String> getTranscripts(String meetingId) async {
    final response = await http.get(
      _uri('/api/meetings/$meetingId/transcript'),
      headers: _headers,
    );
    _throwOnError(response);
    return _pretty(response.body);
  }

  Future<String> summarize(String meetingId) async {
    final response = await http.post(
      _uri('/api/ai/summarize'),
      headers: _headers,
      body: jsonEncode({'meeting_id': meetingId}),
    );
    _throwOnError(response);
    return _pretty(response.body);
  }

  Future<String> extractActionItems(String meetingId) async {
    final response = await http.post(
      _uri('/api/ai/extract-action-items'),
      headers: _headers,
      body: jsonEncode({'meeting_id': meetingId}),
    );
    _throwOnError(response);
    return _pretty(response.body);
  }

  WebSocketChannel connectWebSocket(String meetingId) {
    final uri = Uri.parse('$baseUrl/ws/meetings/$meetingId?token=$token');
    return WebSocketChannel.connect(uri);
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 400) {
      throw http.ClientException(
        'Request failed (${response.statusCode}): ${response.body}',
        response.request?.url,
      );
    }
  }

  String _pretty(String body) {
    try {
      final decoded = jsonDecode(body);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return body;
    }
  }
}
