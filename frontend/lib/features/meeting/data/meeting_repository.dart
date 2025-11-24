import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/meeting_models.dart';
import 'meeting_api.dart';

class MeetingRepository {
  const MeetingRepository(this._api);

  final MeetingApi _api;

  Future<MeetingDetail> fetchMeeting(String meetingId) {
    return _api.fetchMeeting(meetingId);
  }

  Future<List<MeetingAttendee>> fetchAttendees(String meetingId) {
    return _api.fetchAttendees(meetingId);
  }

  Future<String> requestSummary(String meetingId) {
    return _api.requestSummary(meetingId);
  }

  Future<List<MeetingActionItem>> requestActionItems(String meetingId) {
    return _api.requestActionItems(meetingId);
  }

  Future<MeetingActionItem> createActionItem(
    String meetingId,
    ActionItemInput input,
  ) {
    return _api.createActionItem(meetingId, input);
  }

  Future<void> endMeeting(String meetingId) {
    return _api.endMeeting(meetingId);
  }

  WebSocketChannel connect(String meetingId) {
    return _api.connectToMeeting(meetingId);
  }

  Future<void> registerAttendee(
    String meetingId, {
    String? userId,
    String? guestName,
  }) {
    return _api.registerAttendee(
      meetingId,
      userId: userId,
      guestName: guestName,
    );
  }

  Future<TranscriptSegment> submitTranscript({
    required String meetingId,
    required String speaker,
    required String text,
    required String timestamp,
  }) {
    return _api.addTranscript(
      meetingId: meetingId,
      speaker: speaker,
      text: text,
      timestamp: timestamp,
    );
  }
}
