import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../../data/dashboard_repository.dart';
import '../../models/dashboard_models.dart';

class DashboardState {
  const DashboardState({
    this.isLoading = false,
    this.isCreatingActionItem = false,
    this.data,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isCreatingActionItem;
  final DashboardData? data;
  final String? errorMessage;

  DashboardState copyWith({
    bool? isLoading,
    bool? isCreatingActionItem,
    DashboardData? data,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isCreatingActionItem: isCreatingActionItem ?? this.isCreatingActionItem,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repository, this._onUnauthorized)
    : super(const DashboardState());

  final DashboardRepository _repository;
  final void Function() _onUnauthorized;

  Future<void> load(String teamId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repository.fetchDashboard(teamId);
      state = DashboardState(isLoading: false, data: data);
    } on UnauthorizedException catch (error) {
      state = DashboardState(isLoading: false, errorMessage: error.message);
      _onUnauthorized();
    } on http.ClientException catch (error) {
      state = DashboardState(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = DashboardState(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> refresh(String teamId) => load(teamId);

  Future<void> createActionItem({
    required String meetingId,
    required String type,
    required String assignee,
    required String content,
    String status = 'pending',
    DateTime? dueDate,
  }) async {
    final current = state.data;
    if (current == null) {
      throw StateError('Dashboard data not loaded');
    }
    state = state.copyWith(isCreatingActionItem: true, errorMessage: null);
    try {
      final item = await _repository.createActionItem(
        meetingId: meetingId,
        type: type,
        assignee: assignee,
        content: content,
        status: status,
        dueDate: dueDate,
      );
      final updatedItems = [item, ...current.actionItems];
      state = state.copyWith(
        isCreatingActionItem: false,
        data: DashboardData(
          team: current.team,
          actionItems: updatedItems,
          meetings: current.meetings,
        ),
      );
    } on UnauthorizedException catch (error) {
      state = state.copyWith(
        isCreatingActionItem: false,
        errorMessage: error.message,
      );
      _onUnauthorized();
    } on http.ClientException catch (error) {
      state = state.copyWith(
        isCreatingActionItem: false,
        errorMessage: error.message,
      );
      rethrow;
    } catch (error) {
      state = state.copyWith(
        isCreatingActionItem: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }
}
