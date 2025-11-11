import 'auth_api.dart';

class AuthRepository {
  AuthRepository(this._api);

  final AuthApi _api;

  Future<void> login(String email, String password) => _api.login(email, password);

  Future<void> signup(String email, String password) => _api.signup(email, password);
}
