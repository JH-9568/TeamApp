import 'package:frontend/common/models/user.dart';

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final User user;
  final String token;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    return AuthSession(
      user: User.fromJson(userJson),
      token: json['token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), 'token': token};
  }
}
