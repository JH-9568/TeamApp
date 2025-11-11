import 'package:flutter/material.dart';

import '../routes/app_router.dart';

class TeamMeetingApp extends StatelessWidget {
  const TeamMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Team Meeting Client',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
