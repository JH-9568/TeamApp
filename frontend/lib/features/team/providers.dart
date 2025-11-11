import 'data/team_api.dart';
import 'data/team_repository.dart';

class TeamProviders {
  TeamProviders._();

  static final TeamRepository repository = TeamRepository(TeamApi());
}
