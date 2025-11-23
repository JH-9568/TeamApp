import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/common/models/user.dart';
import 'package:frontend/features/auth/providers.dart';
import 'data/mypage_api.dart';
import 'data/mypage_repository.dart';
import 'presentation/controllers/mypage_controller.dart';

final myPageApiProvider = Provider<MyPageApi>((ref) {
  final token = ref.watch(
    authControllerProvider.select((state) => state.session?.token),
  );
  return MyPageApi(token: token);
});

final myPageRepositoryProvider = Provider<MyPageRepository>(
  (ref) => MyPageRepository(ref.watch(myPageApiProvider)),
);

final myPageControllerProvider =
    StateNotifierProvider<MyPageController, MyPageState>((ref) {
      Future<bool> handleUnauthorized() async {
        final refreshed =
            await ref.read(authControllerProvider.notifier).refreshSession();
        if (!refreshed) {
          ref.read(authControllerProvider.notifier).logout();
        }
        return refreshed;
      }

      void handleUserUpdated(User user) {
        ref.read(authControllerProvider.notifier).updateUser(user);
      }

      final initialUser = ref.read(authControllerProvider).session?.user;
      return MyPageController(
        ref.watch(myPageRepositoryProvider),
        handleUnauthorized,
        handleUserUpdated,
        initialUser,
      );
    });
