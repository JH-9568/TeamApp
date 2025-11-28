import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/meeting_repository.dart';
import '../../models/meeting_models.dart';

const _unset = Object();

class MeetingState {
  const MeetingState({
    this.isLoading = true,
    this.isSummaryLoading = false,
    this.isActionSyncing = false,
    this.isSubmittingAction = false,
    this.isSubmittingTranscript = false,
    this.isConnected = false,
    this.errorMessage,
    this.meeting,
    this.attendees = const [],
  });

  final bool isLoading;
  final bool isSummaryLoading;
  final bool isActionSyncing;
  final bool isSubmittingAction;
  final bool isSubmittingTranscript;
  final bool isConnected;
  final String? errorMessage;
  final MeetingDetail? meeting;
  final List<MeetingAttendee> attendees;

  List<TranscriptSegment> get transcripts => meeting?.transcripts ?? [];

  List<MeetingActionItem> get actionItems => meeting?.actionItems ?? [];

  List<SpeakerStat> get speakerStats => meeting?.speakerStats ?? [];

  MeetingState copyWith({
    bool? isLoading,
    bool? isSummaryLoading,
    bool? isActionSyncing,
    bool? isSubmittingAction,
    bool? isSubmittingTranscript,
    bool? isConnected,
    Object? errorMessage = _unset,
    MeetingDetail? meeting,
    List<MeetingAttendee>? attendees,
  }) {
    return MeetingState(
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      isActionSyncing: isActionSyncing ?? this.isActionSyncing,
      isSubmittingAction: isSubmittingAction ?? this.isSubmittingAction,
      isSubmittingTranscript:
          isSubmittingTranscript ?? this.isSubmittingTranscript,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      meeting: meeting ?? this.meeting,
      attendees: attendees ?? this.attendees,
    );
  }
}

class MeetingController extends StateNotifier<MeetingState> {
  MeetingController(
    this._repository,
    this.meetingId, {
    required this.userId,
    required this.userName,
  }) : super(const MeetingState());

  final MeetingRepository _repository;
  final String meetingId;
  final String? userId;
  final String userName;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _initialized = false;
  bool _attendeeRegistered = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await load();
    await _registerAttendee();
    _connect();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: _unset);
    try {
      final meeting = await _repository.fetchMeeting(meetingId);
      final attendees = await _repository.fetchAttendees(meetingId);
      final transcript = await _repository.fetchTranscript(meetingId);
      final mergedMeeting = meeting.copyWith(transcripts: transcript);
      state = state.copyWith(
        isLoading: false,
        meeting: mergedMeeting,
        attendees: attendees,
        errorMessage: null,
      );
    } catch (error, stack) {
      debugPrint('Failed to load meeting: $error\n$stack');
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> refresh() => load();

  Future<void> requestSummary() async {
    if (state.isSummaryLoading) return;
    if (state.transcripts.isEmpty) {
      state = state.copyWith(errorMessage: '실시간 자막이 기록된 후에 요약을 생성할 수 있습니다.');
      return;
    }
    state = state.copyWith(isSummaryLoading: true);
    try {
      final summary = await _repository.requestSummary(meetingId);
      _updateMeeting(state.meeting?.copyWith(summary: summary));
    } catch (error, stack) {
      debugPrint('Failed to summarize: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  Future<void> extractActionItems() async {
    if (state.isActionSyncing) return;
    if (state.transcripts.isEmpty) {
      state = state.copyWith(
        errorMessage: '실시간 자막이 기록된 후에 액션 아이템을 추출할 수 있습니다.',
      );
      return;
    }
    state = state.copyWith(isActionSyncing: true);
    try {
      final items = await _repository.requestActionItems(meetingId);
      if (items.isNotEmpty) {
        _updateMeeting(state.meeting?.copyWith(actionItems: items));
      }
    } catch (error, stack) {
      debugPrint('Failed to sync action items: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      state = state.copyWith(isActionSyncing: false);
    }
  }

  Future<void> addActionItem(ActionItemInput input) async {
    if (state.isSubmittingAction) return;
    state = state.copyWith(isSubmittingAction: true);
    try {
      final created = await _repository.createActionItem(meetingId, input);
      final updated = [created, ...state.actionItems];
      _updateMeeting(state.meeting?.copyWith(actionItems: updated));
    } catch (error, stack) {
      debugPrint('Failed to add action item: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      state = state.copyWith(isSubmittingAction: false);
    }
  }

  Future<void> updateActionItemStatus(
    String actionItemId,
    String status,
  ) async {
    try {
      final updated = await _repository.updateActionItem(
        actionItemId,
        status: status,
      );
      final items = state.actionItems.map((item) {
        return item.id == actionItemId ? updated : item;
      }).toList();
      _updateMeeting(state.meeting?.copyWith(actionItems: items));
    } catch (error, stack) {
      debugPrint('Failed to update action item: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> deleteActionItem(String actionItemId) async {
    try {
      await _repository.deleteActionItem(actionItemId);
      final items = state.actionItems
          .where((item) => item.id != actionItemId)
          .toList();
      _updateMeeting(state.meeting?.copyWith(actionItems: items));
    } catch (error, stack) {
      debugPrint('Failed to delete action item: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> submitTranscript(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSubmittingTranscript) {
      return;
    }
    state = state.copyWith(isSubmittingTranscript: true);
    try {
      final segment = await _repository.submitTranscript(
        meetingId: meetingId,
        speaker: userName,
        text: trimmed,
        timestamp: DateTime.now().toIso8601String(),
      );
      final transcripts = [...state.transcripts, segment];
      _updateMeeting(state.meeting?.copyWith(transcripts: transcripts));
    } catch (error, stack) {
      debugPrint('Failed to submit transcript: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    } finally {
      state = state.copyWith(isSubmittingTranscript: false);
    }
  }

  Future<void> endMeeting() async {
    try {
      await _repository.endMeeting(meetingId);
      _updateMeeting(state.meeting?.copyWith(status: 'completed'));
    } catch (error, stack) {
      debugPrint('Failed to end meeting: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  void _updateMeeting(MeetingDetail? meeting) {
    if (meeting == null) return;
    final stats = _computeSpeakerStats(meeting.transcripts);
    final meetingWithStats = meeting.copyWith(speakerStats: stats);
    state = state.copyWith(meeting: meetingWithStats);
  }

  Future<void> _registerAttendee() async {
    if (_attendeeRegistered) return;
    try {
      final fallbackName = userName.isNotEmpty ? userName : '참여자';
      await _repository.registerAttendee(
        meetingId,
        userId: userId,
        guestName: fallbackName,
      );
      final attendees = await _repository.fetchAttendees(meetingId);
      state = state.copyWith(attendees: attendees);
      _attendeeRegistered = true;
    } catch (error, stack) {
      debugPrint('Failed to register attendee: $error\n$stack');
    }
  }

  void _connect() {
    try {
      debugPrint('[MeetingController] Connecting websocket for $meetingId');
      _channel = _repository.connect(meetingId);
      _subscription = _channel!.stream.listen(
        _handleSocketEvent,
        onDone: () => state = state.copyWith(isConnected: false),
        onError: (error) {
          debugPrint('Meeting socket error: $error');
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (error, stack) {
      debugPrint('Failed to open meeting socket: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  void sendAudioChunk(Uint8List data) {
    final channel = _channel;
    final meetingStatus = state.meeting?.status;
    if (channel == null || meetingStatus != 'in-progress') return;
    try {
      if (_isSilent(data)) {
        return;
      }
      final speakerLabel = userName.isNotEmpty ? userName : '참여자';
      channel.sink.add(
        jsonEncode({
          'type': 'audio_chunk',
          'data': {
            'data': base64Encode(data),
            'speaker': speakerLabel,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );
    } catch (error, stack) {
      debugPrint('Failed to send audio chunk: $error\n$stack');
    }
  }

  void _handleSocketEvent(dynamic raw) {
    try {
      Map<String, dynamic>? message;
      if (raw is String) {
        message = jsonDecode(raw) as Map<String, dynamic>?;
      } else if (raw is Map) {
        message = Map<String, dynamic>.from(raw);
      }
      if (message == null) {
        return;
      }

      final type = message['type'] as String?;
      final data = message['data'];
      final payload =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      if (type == null || type == 'ack') {
        return;
      }

      debugPrint('[MeetingSocket] type=$type data=$payload');

      switch (type) {
        case 'ready':
          debugPrint('[MeetingSocket] READY event');
          state = state.copyWith(isConnected: true);
          break;
        case 'transcript_segment':
          final segment = TranscriptSegment.fromJson(payload);
          final transcripts = [...state.transcripts, segment];
          _updateMeeting(state.meeting?.copyWith(transcripts: transcripts));
          break;
        case 'summary_update':
          final summary = payload['summary'] as String?;
          if (summary != null) {
            _updateMeeting(state.meeting?.copyWith(summary: summary));
          }
          break;
        default:
          debugPrint('[MeetingSocket] Ignoring unknown event type "$type"');
          break;
      }
    } catch (error, stack) {
      debugPrint('Failed to handle meeting socket event: $error\n$stack');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> saveSpeakerStats() async {
    final stats = state.speakerStats;
    if (stats.isEmpty) return;
    try {
      await _repository.saveSpeakerStats(meetingId, stats);
    } catch (error, stack) {
      debugPrint('Failed to save speaker stats: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<RecordingUploadInfo?> requestRecordingUpload() async {
    try {
      final info = await _repository.requestRecordingUpload(meetingId);
      return info;
    } catch (error, stack) {
      debugPrint('Failed to request recording upload: $error\n$stack');
      state = state.copyWith(errorMessage: error.toString());
      return null;
    }
  }

  void sendPing() {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({'type': 'ping'}));
    } catch (error, stack) {
      debugPrint('Failed to send ping: $error\n$stack');
    }
  }

  void requestSummaryOverSocket(String prompt) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(
        jsonEncode({
          'type': 'summary_request',
          'data': {'prompt': prompt},
        }),
      );
    } catch (error, stack) {
      debugPrint('Failed to send summary request: $error\n$stack');
    }
  }

  bool _isSilent(Uint8List data) {
    if (data.isEmpty) {
      return true;
    }
    final byteData = data.buffer.asByteData();
    final sampleCount = data.lengthInBytes ~/ 2;
    if (sampleCount == 0) {
      return true;
    }
    double sum = 0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little).toDouble();
      sum += sample * sample;
    }
    final rms = sqrt(sum / sampleCount);
    // Treat very low RMS as silence; keep threshold modest to avoid dropping speech
    return rms < 800;
  }

  List<SpeakerStat> _computeSpeakerStats(List<TranscriptSegment> transcripts) {
    if (transcripts.isEmpty) return const [];

    final totals = <String, _SpeakerAgg>{};
    for (final t in transcripts) {
      final speaker = (t.speaker.isNotEmpty ? t.speaker : '참여자').trim();
      final textLen = t.text.trim().length;
      final agg = totals.putIfAbsent(speaker, () => _SpeakerAgg());
      agg.count += 1;
      agg.totalLength += textLen;
    }

    final totalSegments = transcripts.length;
    final stats = totals.entries.map((entry) {
      final speaker = entry.key;
      final agg = entry.value;
      final avgLen = agg.count > 0 ? agg.totalLength / agg.count : 0.0;
      final participation = totalSegments > 0 ? (agg.count / totalSegments) * 100.0 : 0.0;
      return SpeakerStat(
        id: 'local-$speaker',
        speaker: speaker,
        speakTime: agg.totalLength, // proxy: total text length
        speakCount: agg.count,
        participationRate: participation,
        avgLength: avgLen,
      );
    }).toList()
      ..sort((a, b) => b.speakTime.compareTo(a.speakTime));

    return stats;
  }
}

class _SpeakerAgg {
  int count = 0;
  int totalLength = 0;
}
