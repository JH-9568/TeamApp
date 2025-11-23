import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/auth/providers.dart';

import 'data/team_api.dart';
import 'data/team_repository.dart';
import 'presentation/controllers/team_selection_controller.dart';

final teamApiProvider = Provider<TeamApi>((ref) {
  final authState = ref.watch(authControllerProvider);
  final token = authState.session?.token;
  return TeamApi(token: token);
});

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(teamApiProvider)),
);

final teamSelectionControllerProvider =
    StateNotifierProvider<TeamSelectionController, TeamSelectionState>(
      (ref) => TeamSelectionController(ref.watch(teamRepositoryProvider)),
    );
