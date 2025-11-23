class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = '인증이 만료되었습니다. 다시 로그인해주세요.']);

  final String message;

  @override
  String toString() => message;
}
