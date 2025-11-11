import 'data/auth_api.dart';
import 'data/auth_repository.dart';

class AuthProviders {
  AuthProviders._();

  static final AuthRepository repository = AuthRepository(AuthApi());
}
