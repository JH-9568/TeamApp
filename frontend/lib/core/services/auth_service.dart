import 'dart:convert';

import '../../common/models/user.dart';
import '../../features/auth/models/auth_session.dart';
import 'storage_service.dart';

class AuthService {
  const AuthService(this._storageService);

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final StorageService _storageService;

  Future<void> persistSession(AuthSession session) async {
    await _storageService.save(_tokenKey, session.token);
    await _storageService.save(_userKey, jsonEncode(session.user.toJson()));
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _storageService.read(_tokenKey);
    final userJson = await _storageService.read(_userKey);
    if (token == null || userJson == null) {
      return null;
    }
    final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    return AuthSession(user: user, token: token);
  }

  Future<void> clearSession() async {
    await _storageService.delete(_tokenKey);
    await _storageService.delete(_userKey);
  }

  Future<String?> token() => _storageService.read(_tokenKey);
}
