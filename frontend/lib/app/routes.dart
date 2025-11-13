enum AppRoute {
  login('/'),
  register('/register'),
  teamSelection('/teams'),
  dashboard('/dashboard'),
  myPage('/mypage'),
  voiceMeeting('/meetings/live'),
  meetingDetail('/meetings/detail');

  const AppRoute(this.path);

  final String path;
}
