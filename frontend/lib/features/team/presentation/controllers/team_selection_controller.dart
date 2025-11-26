import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/errors/unauthorized_exception.dart';

import '../../../team/data/team_repository.dart';
import '../../../team/models/team.dart';

const _unset = Object();

class TeamSelectionState {
  const TeamSelectionState({
    this.teams = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.isJoining = false,
    this.errorMessage,
    this.selectedTeam,
  });

  final List<Team> teams;
  final bool isLoading;
  final bool isCreating;
  final bool isJoining;
  final String? errorMessage;
  final Team? selectedTeam;

  TeamSelectionState copyWith({
    List<Team>? teams,
    bool? isLoading,
    bool? isCreating,
    bool? isJoining,
    Object? errorMessage = _unset,
    Object? selectedTeam = _unset,
  }) {
    return TeamSelectionState(
      teams: teams ?? this.teams,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isJoining: isJoining ?? this.isJoining,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      selectedTeam: identical(selectedTeam, _unset)
          ? this.selectedTeam
          : selectedTeam as Team?,
    );
  }
}

class TeamSelectionController extends StateNotifier<TeamSelectionState> {
  TeamSelectionController(this._repository, this._onUnauthorized)
    : super(const TeamSelectionState());

  final TeamRepository _repository;
  final Future<bool> Function() _onUnauthorized;

  Future<void> loadTeams() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final teams = await _repository.fetchTeams();
      state = state.copyWith(
        isLoading: false,
        teams: teams,
        errorMessage: null,
      );
    } on UnauthorizedException catch (error) {
      debugPrint(
        '[TeamSelectionController] loadTeams unauthorized: ${error.message}',
      );
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return loadTeams();
      }
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on http.ClientException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<Team> createTeam(String name) async {
    state = state.copyWith(isCreating: true, errorMessage: null);
    try {
      final team = await _repository.createTeam(name);
      state = state.copyWith(
        isCreating: false,
        teams: [...state.teams, team],
        errorMessage: null,
      );
      return team;
    } on UnauthorizedException catch (error) {
      debugPrint(
        '[TeamSelectionController] createTeam unauthorized: ${error.message}',
      );
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return createTeam(name);
      }
      state = state.copyWith(isCreating: false, errorMessage: error.message);
      rethrow;
    } on http.ClientException catch (error) {
      state = state.copyWith(isCreating: false, errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = state.copyWith(isCreating: false, errorMessage: error.toString());
      rethrow;
    }
  }

  Future<Team> joinTeam(String inviteCode) async {
    state = state.copyWith(isJoining: true, errorMessage: null);
    try {
      final team = await _repository.joinTeam(inviteCode);
      final exists = state.teams.any((item) => item.id == team.id);
      final updatedTeams = exists
          ? state.teams.map((item) => item.id == team.id ? team : item).toList()
          : [...state.teams, team];
      state = state.copyWith(
        isJoining: false,
        teams: updatedTeams,
        errorMessage: null,
      );
      return team;
    } on UnauthorizedException catch (error) {
      debugPrint(
        '[TeamSelectionController] joinTeam unauthorized: ${error.message}',
      );
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return joinTeam(inviteCode);
      }
      state = state.copyWith(isJoining: false, errorMessage: error.message);
      rethrow;
    } on http.ClientException catch (error) {
      state = state.copyWith(isJoining: false, errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = state.copyWith(isJoining: false, errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> updateTeamName(String teamId, String name) async {
    try {
      final updated = await _repository.updateTeam(teamId, name);
      final teams = state.teams
          .map((team) => team.id == updated.id ? updated : team)
          .toList();
      final selected = state.selectedTeam?.id == updated.id
          ? updated
          : state.selectedTeam;
      state = state.copyWith(teams: teams, selectedTeam: selected);
    } on UnauthorizedException catch (error) {
      debugPrint(
        '[TeamSelectionController] updateTeam unauthorized: ${error.message}',
      );
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return updateTeamName(teamId, name);
      }
      state = state.copyWith(errorMessage: error.message);
      rethrow;
    } on http.ClientException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      rethrow;
    }
  }

  void selectTeam(Team team) {
    state = state.copyWith(selectedTeam: team);
  }

  void reset() {
    state = const TeamSelectionState();
  }

  Future<bool> _handleUnauthorized() async {
    final refreshed = await _onUnauthorized();
    if (!refreshed) {
      reset();
    }
    return refreshed;
  }
}
