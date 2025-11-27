import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/auth/providers.dart';

import 'data/meeting_api.dart';
import 'data/meeting_repository.dart';
import 'presentation/controllers/meeting_controller.dart';

final meetingApiProvider = Provider<MeetingApi>((ref) {
  final token = ref.watch(
    authControllerProvider.select((state) => state.session?.token),
  );
  return MeetingApi(token: token);
});

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => MeetingRepository(ref.watch(meetingApiProvider)),
);

final meetingControllerProvider =
    StateNotifierProvider.autoDispose.family<MeetingController, MeetingState, String>((
      ref,
      meetingId,
    ) {
      final user = ref.read(authControllerProvider).session?.user;
      final controller = MeetingController(
        ref.watch(meetingRepositoryProvider),
        meetingId,
        userId: user?.id,
        userName: user?.name ?? '나',
      );
      controller.initialize();
      return controller;
    });
