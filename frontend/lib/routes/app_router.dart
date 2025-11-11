import 'package:flutter/material.dart';

import '../features/meeting/presentation/pages/home_page.dart';

class AppRouter {
  static const home = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}
