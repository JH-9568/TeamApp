class MeetingProvider {
  static final MeetingProvider instance = MeetingProvider._();
  MeetingProvider._();

  String baseUrl = 'http://127.0.0.1:8000';

  void updateBaseUrl(String value) {
    baseUrl = value.trim();
  }
}
