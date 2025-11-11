import 'team_api.dart';

class TeamRepository {
  TeamRepository(this._api);

  final TeamApi _api;

  Future<void> fetchTeams() {
    return _api.fetchTeams();
  }
}
