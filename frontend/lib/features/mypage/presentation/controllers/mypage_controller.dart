import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/common/models/user.dart';
import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../../data/mypage_repository.dart';

class MyPageState {
  const MyPageState({
    this.user,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final User? user;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  MyPageState copyWith({
    User? user,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return MyPageState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class MyPageController extends StateNotifier<MyPageState> {
  MyPageController(
    this._repository,
    this._onUnauthorized,
    this._onUserUpdated,
    User? initialUser,
  ) : super(MyPageState(user: initialUser));

  final MyPageRepository _repository;
  final Future<bool> Function() _onUnauthorized;
  final void Function(User user) _onUserUpdated;

  Future<void> loadProfile() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.fetchProfile();
      if (!mounted) return;
      _onUserUpdated(user);
      state = state.copyWith(isLoading: false, user: user);
    } on UnauthorizedException catch (error) {
      if (!mounted) return;
      debugPrint(
        '[MyPageController] loadProfile unauthorized: ${error.message}',
      );
      final refreshed = await _onUnauthorized();
      if (refreshed) {
        return loadProfile();
      }
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on http.ClientException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> updateProfile({String? name, String? avatar}) async {
    if (name == null && avatar == null) return;
    if (!mounted) return;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final user = await _repository.updateProfile(name: name, avatar: avatar);
      if (!mounted) return;
      _onUserUpdated(user);
      state = state.copyWith(isSaving: false, user: user);
    } on UnauthorizedException catch (error) {
      if (!mounted) return;
      debugPrint(
        '[MyPageController] updateProfile unauthorized: ${error.message}',
      );
      final refreshed = await _onUnauthorized();
      if (refreshed) {
        return updateProfile(name: name, avatar: avatar);
      }
      state = state.copyWith(isSaving: false, errorMessage: error.message);
    } on http.ClientException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      rethrow;
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      rethrow;
    }
  }
}
