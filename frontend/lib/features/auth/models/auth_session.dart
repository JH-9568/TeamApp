import 'package:frontend/common/models/user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.refreshToken,
  });

  final User user;
  final String token;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>;
    return AuthSession(
      user: User.fromJson(userJson),
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      'refreshToken': refreshToken,
    };
  }
}
