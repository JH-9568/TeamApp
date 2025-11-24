import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../../data/dashboard_repository.dart';
import '../../models/dashboard_models.dart';

class DashboardState {
  const DashboardState({
    this.isLoading = false,
    this.isCreatingActionItem = false,
    this.isCreatingMeeting = false,
    this.data,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isCreatingActionItem;
  final bool isCreatingMeeting;
  final DashboardData? data;
  final String? errorMessage;

  DashboardState copyWith({
    bool? isLoading,
    bool? isCreatingActionItem,
    bool? isCreatingMeeting,
    DashboardData? data,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isCreatingActionItem: isCreatingActionItem ?? this.isCreatingActionItem,
      isCreatingMeeting: isCreatingMeeting ?? this.isCreatingMeeting,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repository, this._onUnauthorized)
    : super(const DashboardState());

  final DashboardRepository _repository;
  final Future<bool> Function() _onUnauthorized;

  Future<void> load(String teamId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repository.fetchDashboard(teamId);
      state = DashboardState(isLoading: false, data: data);
    } on UnauthorizedException catch (error) {
      debugPrint('[DashboardController] load unauthorized: ${error.message}');
      final refreshed = await _onUnauthorized();
      if (refreshed) {
        return load(teamId);
      }
      state = DashboardState(isLoading: false, errorMessage: error.message);
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
      debugPrint(
        '[DashboardController] createActionItem unauthorized: ${error.message}',
      );
      final refreshed = await _onUnauthorized();
      if (refreshed) {
        state = state.copyWith(isCreatingActionItem: false);
        return createActionItem(
          meetingId: meetingId,
          type: type,
          assignee: assignee,
          content: content,
          status: status,
          dueDate: dueDate,
        );
      }
      state = state.copyWith(
        isCreatingActionItem: false,
        errorMessage: error.message,
      );
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

  Future<DashboardMeeting> createMeeting({
    required String teamId,
    required String title,
  }) async {
    state = state.copyWith(isCreatingMeeting: true, errorMessage: null);
    try {
      final meeting = await _repository.createMeeting(
        teamId: teamId,
        title: title,
      );
      final current = state.data;
      if (current != null) {
        state = state.copyWith(
          isCreatingMeeting: false,
          data: DashboardData(
            team: current.team,
            actionItems: current.actionItems,
            meetings: [meeting, ...current.meetings],
          ),
        );
      } else {
        state = state.copyWith(isCreatingMeeting: false);
      }
      return meeting;
    } on UnauthorizedException catch (error) {
      debugPrint(
        '[DashboardController] createMeeting unauthorized: ${error.message}',
      );
      final refreshed = await _onUnauthorized();
      state = state.copyWith(isCreatingMeeting: false);
      if (refreshed) {
        return createMeeting(teamId: teamId, title: title);
      }
      throw http.ClientException(error.message);
    } on http.ClientException {
      state = state.copyWith(isCreatingMeeting: false);
      rethrow;
    } catch (error) {
      state = state.copyWith(
        isCreatingMeeting: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }
}
