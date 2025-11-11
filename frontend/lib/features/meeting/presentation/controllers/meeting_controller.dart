import 'package:flutter/material.dart';

class MeetingController extends ChangeNotifier {
  String meetingId = '';
  String token = '';

  void updateMeeting(String value) {
    meetingId = value.trim();
    notifyListeners();
  }

  void updateToken(String value) {
    token = value.trim();
    notifyListeners();
  }
}
