import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/core/services/storage_service.dart';

import 'data/auth_api.dart';
import 'data/auth_repository.dart';
import 'presentation/controllers/auth_controller.dart';

final storageServiceProvider = Provider<StorageService>(
  (ref) => const StorageService(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(storageServiceProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(AuthApi()),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.read(authRepositoryProvider),
    ref.read(authServiceProvider),
  ),
);
