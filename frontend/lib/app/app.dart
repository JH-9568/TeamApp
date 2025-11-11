import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class TeamMeetingApp extends StatelessWidget {
  const TeamMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Team Meeting Client',
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
