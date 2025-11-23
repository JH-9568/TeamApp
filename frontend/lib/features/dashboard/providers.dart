import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/auth/providers.dart';
import 'data/dashboard_api.dart';
import 'data/dashboard_repository.dart';
import 'presentation/controllers/dashboard_controller.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  final token = ref.watch(
    authControllerProvider.select((state) => state.session?.token),
  );
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
      Future<bool> handleUnauthorized() async {
        final refreshed =
            await ref.read(authControllerProvider.notifier).refreshSession();
        if (!refreshed) {
          ref.read(authControllerProvider.notifier).logout();
        }
        return refreshed;
      }

      final controller = DashboardController(
        ref.watch(dashboardRepositoryProvider),
        handleUnauthorized,
      );
      controller.load(teamId);
      return controller;
    });
