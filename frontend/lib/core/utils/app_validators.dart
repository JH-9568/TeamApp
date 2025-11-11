class AppValidators {
  const AppValidators._();

  static String? notEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '필수 입력 항목입니다.';
    }
    return null;
  }
}
