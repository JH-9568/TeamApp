import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/common/models/user.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/features/auth/models/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = const StorageService();
    authService = AuthService(storage);
  });

  test('persistSession -> restoreSession roundtrip works', () async {
    final session = AuthSession(
      user: User(id: 'u1', name: 'Jane', email: 'jane@example.com'),
      token: 'access-token',
      refreshToken: 'refresh-token',
    );

    await authService.persistSession(session);
    final restored = await authService.restoreSession();

    expect(restored, isNotNull);
    expect(restored!.user.email, equals('jane@example.com'));
    expect(restored.token, equals('access-token'));
    expect(restored.refreshToken, equals('refresh-token'));
  });

  test('clearSession removes all stored keys', () async {
    final session = AuthSession(
      user: User(id: 'u1', name: 'Jane', email: 'jane@example.com'),
      token: 'access-token',
      refreshToken: 'refresh-token',
    );
    await authService.persistSession(session);

    await authService.clearSession();
    final restored = await authService.restoreSession();

    expect(restored, isNull);
  });
}
