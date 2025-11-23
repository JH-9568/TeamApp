import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/auth/providers.dart';
import 'package:frontend/features/team/providers.dart';

import 'data/dashboard_api.dart';
import 'data/dashboard_repository.dart';
import 'presentation/controllers/dashboard_controller.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  final authState = ref.watch(authControllerProvider);
  final token = authState.session?.token;
  return DashboardApi(token: token);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(dashboardApiProvider)),
);

final dashboardControllerProvider =
    StateNotifierProvider.family<DashboardController, DashboardState, String>((
      ref,
      teamId,
    ) {
      void handleUnauthorized() {
        ref.read(authControllerProvider.notifier).logout();
        ref.read(teamSelectionControllerProvider.notifier).reset();
      }

      final controller = DashboardController(
        ref.watch(dashboardRepositoryProvider),
        handleUnauthorized,
      );
      controller.load(teamId);
      return controller;
    });
