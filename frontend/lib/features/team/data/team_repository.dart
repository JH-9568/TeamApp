import '../models/team.dart';
import 'team_api.dart';

class TeamRepository {
  TeamRepository(this._api);

  final TeamApi _api;

  Future<List<Team>> fetchTeams() {
    return _api.fetchTeams();
  }

  Future<Team> createTeam(String name) {
    return _api.createTeam(name);
  }

  Future<Team> joinTeam(String inviteCode) {
    return _api.joinTeam(inviteCode);
  }
}
