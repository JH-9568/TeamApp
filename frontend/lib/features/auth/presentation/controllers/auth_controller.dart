import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/services/auth_service.dart';

import '../../data/auth_repository.dart';
import '../../models/auth_session.dart';

enum AuthStatus { restoring, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isRestoring => status == AuthStatus.restoring;
  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.error && errorMessage != null;
  bool get isInitialized => status != AuthStatus.restoring;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._authService)
    : super(const AuthState()) {
    debugPrint('[AuthController] Initializing and restoring session...');
    _restoreSession();
  }

  final AuthRepository _repository;
  final AuthService _authService;

  Future<void> _restoreSession() async {
    try {
      final session = await _authService.restoreSession();
      if (session != null) {
        debugPrint(
          '[AuthController] Session restored for user ${session.user.email}',
        );
        state = AuthState(status: AuthStatus.authenticated, session: session);
      } else {
        debugPrint('[AuthController] No stored session found.');
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (error) {
      debugPrint('[AuthController] Failed to restore session: $error');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '세션 복원에 실패했습니다. 다시 로그인해주세요. ($error)',
      );
    }
  }

  Future<void> login(String email, String password) async {
    if (state.isLoading || state.isRestoring) return;

    debugPrint('[AuthController] login() called for $email');
    state = const AuthState(status: AuthStatus.loading);
    try {
      final session = await _repository.login(email, password);
      await _authService.persistSession(session);
      debugPrint('[AuthController] login() succeeded for $email');
      state = AuthState(status: AuthStatus.authenticated, session: session);
    } on http.ClientException catch (error) {
      debugPrint('[AuthController] login() client error: ${error.message}');
      state = AuthState(status: AuthStatus.error, errorMessage: error.message);
    } catch (error) {
      debugPrint('[AuthController] login() unexpected error: $error');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signup(String name, String email, String password) async {
    if (state.isLoading || state.isRestoring) return;

    debugPrint('[AuthController] signup() called for $email');
    state = const AuthState(status: AuthStatus.loading);
    try {
      final session = await _repository.signup(name, email, password);
      await _authService.persistSession(session);
      debugPrint('[AuthController] signup() succeeded for $email');
      state = AuthState(status: AuthStatus.authenticated, session: session);
    } on http.ClientException catch (error) {
      debugPrint('[AuthController] signup() client error: ${error.message}');
      state = AuthState(status: AuthStatus.error, errorMessage: error.message);
    } catch (error) {
      debugPrint('[AuthController] signup() unexpected error: $error');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _authService.clearSession();
    debugPrint('[AuthController] logout() completed.');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
