import 'meeting_api.dart';

class MeetingRepository {
  MeetingRepository(this._api);

  final MeetingApi _api;

  Future<String> fetchTranscripts(String meetingId) {
    return _api.getTranscripts(meetingId);
  }

  Future<String> summarize(String meetingId) {
    return _api.summarize(meetingId);
  }

  Future<String> fetchActionItems(String meetingId) {
    return _api.extractActionItems(meetingId);
  }
}
