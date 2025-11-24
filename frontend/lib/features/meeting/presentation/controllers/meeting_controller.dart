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
  })
    : super(const MeetingState());

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
      state = state.copyWith(
        isLoading: false,
        meeting: meeting,
        attendees: attendees,
        errorMessage: null,
      );
    } catch (error, stack) {
      debugPrint('Failed to load meeting: $error\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> requestSummary() async {
    if (state.isSummaryLoading) return;
    if (state.transcripts.isEmpty) {
      state = state.copyWith(
        errorMessage: '실시간 자막이 기록된 후에 요약을 생성할 수 있습니다.',
      );
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
    state = state.copyWith(meeting: meeting);
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
    if (channel == null) return;
    try {
      if (_isSilent(data)) {
        return;
      }
      channel.sink.add(
        jsonEncode(
          {
            'type': 'audio_chunk',
            'data': {
              'data': base64Encode(data),
              'speaker': userName,
              'timestamp': DateTime.now().toIso8601String(),
            },
          },
        ),
      );
    } catch (error, stack) {
      debugPrint('Failed to send audio chunk: $error\n$stack');
    }
  }

  void _handleSocketEvent(dynamic raw) {
    debugPrint('[MeetingSocket] raw message: $raw');
    Map<String, dynamic>? message;
    if (raw is String) {
      try {
        message = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        debugPrint('[MeetingSocket] Failed to decode JSON message');
        return;
      }
    } else if (raw is Map<String, dynamic>) {
      message = raw;
    }
    if (message == null) {
      return;
    }
    final type = message['type'] as String?;
    final data = (message['data'] as Map<String, dynamic>?) ?? {};
    debugPrint('[MeetingSocket] type=$type data=$data');
    switch (type) {
      case 'ready':
        debugPrint('[MeetingSocket] READY event');
        state = state.copyWith(isConnected: true);
        break;
      case 'transcript_segment':
        final segment = TranscriptSegment.fromJson(data);
        final transcripts = [...state.transcripts, segment];
        _updateMeeting(state.meeting?.copyWith(transcripts: transcripts));
        break;
      case 'summary_update':
        final summary = data['summary'] as String?;
        if (summary != null) {
          _updateMeeting(state.meeting?.copyWith(summary: summary));
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
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
    return rms < 800;
  }
}
