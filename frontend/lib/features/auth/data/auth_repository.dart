import 'auth_api.dart';
import '../models/auth_session.dart';

class AuthRepository {
  AuthRepository(this._api);

  final AuthApi _api;

  Future<AuthSession> login(String email, String password) =>
      _api.login(email, password);

  Future<AuthSession> signup(String name, String email, String password) =>
      _api.signup(name, email, password);
}
