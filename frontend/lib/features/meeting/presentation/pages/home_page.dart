import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../meeting/data/backend_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _baseUrlController;
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _meetingController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  String _log = 'Ready. Configure the fields and tap a button to send a request.';
  WebSocketChannel? _channel;
  List<String> _wsMessages = const [];

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000',
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _meetingController.dispose();
    _logScrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  BackendClient get _client => BackendClient(
        baseUrl: _baseUrlController.text.trim().replaceAll(RegExp(r'/+$'), ''),
        token: _tokenController.text.trim(),
      );

  Future<void> _runFuture(Future<String> Function() task) async {
    setState(() => _log = 'Loading...');
    try {
      final result = await task();
      setState(() => _log = result);
    } catch (error) {
      setState(() => _log = 'Error: $error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _connectWebSocket() {
    final meetingId = _meetingController.text.trim();
    if (meetingId.isEmpty) {
      setState(() => _log = 'Meeting ID is required for realtime.');
      return;
    }
    _channel?.sink.close();
    try {
      final channel = _client.connectWebSocket(meetingId);
      setState(() {
        _channel = channel;
        _wsMessages = [];
        _log = 'Connected to realtime channel.';
      });
      channel.stream.listen(
        (event) => setState(() {
          _wsMessages = [..._wsMessages, event.toString()];
        }),
        onError: (error) => setState(() {
          _wsMessages = [..._wsMessages, 'Error: $error'];
        }),
        onDone: () => setState(() {
          _wsMessages = [..._wsMessages, 'Connection closed'];
        }),
      );
    } catch (error) {
      setState(() => _log = 'Failed to open WebSocket: $error');
    }
  }

  void _disconnectWebSocket() {
    _channel?.sink.close();
    setState(() {
      _channel = null;
      _wsMessages = [..._wsMessages, 'Disconnected'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Meeting Frontend')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(_baseUrlController, 'Base URL', helper: 'e.g. http://127.0.0.1:8000'),
            const SizedBox(height: 8),
            _buildTextField(_tokenController, 'Bearer Token', obscureText: true),
            const SizedBox(height: 8),
            _buildTextField(_meetingController, 'Meeting ID (UUID)'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => _runFuture(() => _client.getHealth()),
                  child: const Text('Health'),
                ),
                ElevatedButton(
                  onPressed: () => _runFuture(() => _client.getTranscripts(_meetingController.text.trim())),
                  child: const Text('Transcripts'),
                ),
                ElevatedButton(
                  onPressed: () => _runFuture(() => _client.summarize(_meetingController.text.trim())),
                  child: const Text('Summarize'),
                ),
                ElevatedButton(
                  onPressed: () => _runFuture(() => _client.extractActionItems(_meetingController.text.trim())),
                  child: const Text('Action Items'),
                ),
                ElevatedButton(
                  onPressed: _connectWebSocket,
                  child: const Text('Connect WS'),
                ),
                if (_channel != null)
                  OutlinedButton(
                    onPressed: _disconnectWebSocket,
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Response / Logs'),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  controller: _logScrollController,
                  child: Text(_log, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Realtime messages'),
            SizedBox(
              height: 120,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueGrey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _wsMessages.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _wsMessages[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, helperText: helper),
    );
  }
}
