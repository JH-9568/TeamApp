import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/meeting/presentation/screens/meeting_detail_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/start/presentation/start_screen.dart';
import '../features/team/presentation/screens/team_list_screen.dart';

class AppRouter {
  static const start = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const teamSelect = '/teams/select';
  static const home = '/home';
  static const myPage = '/me';
  static const meeting = '/meeting';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case teamSelect:
        return MaterialPageRoute(builder: (_) => const TeamListScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case myPage:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case meeting:
        return MaterialPageRoute(builder: (_) => const MeetingDetailScreen());
      case start:
      default:
        return MaterialPageRoute(builder: (_) => const StartScreen());
    }
  }
}
