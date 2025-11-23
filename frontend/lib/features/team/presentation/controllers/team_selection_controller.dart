import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
  TeamSelectionController(this._repository) : super(const TeamSelectionState());

  final TeamRepository _repository;

  Future<void> loadTeams() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final teams = await _repository.fetchTeams();
      state = state.copyWith(
        isLoading: false,
        teams: teams,
        errorMessage: null,
      );
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
    } on http.ClientException catch (error) {
      state = state.copyWith(isJoining: false, errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = state.copyWith(isJoining: false, errorMessage: error.toString());
      rethrow;
    }
  }

  void selectTeam(Team team) {
    state = state.copyWith(selectedTeam: team);
  }
}
