import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/meeting/presentation/screens/meeting_detail_screen.dart';
import '../features/meeting/presentation/screens/meeting_screen.dart';
import '../features/mypage/presentation/mypage_screen.dart';
import '../features/shell/presentation/app_shell_screen.dart';
import '../features/team/presentation/screens/team_selection_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(_routerNotifierProvider);

  final router = GoRouter(
    initialLocation: AppRoute.login.path,
    refreshListenable: routerNotifier,
    routes: [
      GoRoute(
        path: AppRoute.login.path,
        name: AppRoute.login.name,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.register.path,
        name: AppRoute.register.name,
        builder: (context, state) => const LoginScreen(startInSignup: true),
      ),
      GoRoute(
        path: AppRoute.teamSelection.path,
        name: AppRoute.teamSelection.name,
        builder: (context, state) => const TeamSelectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoute.dashboard.path,
            name: AppRoute.dashboard.name,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoute.myPage.path,
            name: AppRoute.myPage.name,
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.voiceMeeting.path,
        name: AppRoute.voiceMeeting.name,
        builder: (context, state) {
          final meetingId = state.uri.queryParameters['meetingId'];
          return MeetingScreen(meetingId: meetingId);
        },
      ),
      GoRoute(
        path: AppRoute.meetingDetail.path,
        name: AppRoute.meetingDetail.name,
        builder: (context, state) => const MeetingDetailScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = routerNotifier.authState;

      if (!authState.isInitialized) {
        return null;
      }

      final isAuthRoute =
          state.matchedLocation == AppRoute.login.path ||
          state.matchedLocation == AppRoute.register.path;

      if (!authState.isAuthenticated && !isAuthRoute) {
        return AppRoute.login.path;
      }

      if (authState.isAuthenticated && isAuthRoute) {
        return AppRoute.teamSelection.path;
      }

      return null;
    },
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Not found: ${state.uri.path}'))),
  );
  ref.onDispose(router.dispose);
  return router;
});

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _subscription = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  AuthState get authState => _ref.read(authControllerProvider);

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
