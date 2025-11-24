import 'dart:convert';

import '../../common/models/user.dart';
import '../../features/auth/models/auth_session.dart';
import 'storage_service.dart';

class AuthService {
  const AuthService(this._storageService);

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _refreshKey = 'auth_refresh_token';

  final StorageService _storageService;

  Future<void> persistSession(AuthSession session) async {
    await _storageService.save(_tokenKey, session.token);
    await _storageService.save(_userKey, jsonEncode(session.user.toJson()));
    await _storageService.save(_refreshKey, session.refreshToken);
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _storageService.read(_tokenKey);
    final userJson = await _storageService.read(_userKey);
    final refreshToken = await _storageService.read(_refreshKey);
    if (token == null || userJson == null || refreshToken == null) {
      return null;
    }
    final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    return AuthSession(user: user, token: token, refreshToken: refreshToken);
  }

  Future<void> clearSession() async {
    await _storageService.delete(_tokenKey);
    await _storageService.delete(_userKey);
    await _storageService.delete(_refreshKey);
  }

  Future<String?> token() => _storageService.read(_tokenKey);

  Future<String?> refreshToken() => _storageService.read(_refreshKey);
}
