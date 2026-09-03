class CredValidators {
  CredValidators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phMobile = RegExp(r'^(09\d{9}|\+639\d{9}|639\d{9})$');

  static String? required(String? value, {String message = 'Enter this field'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? 'Enter your email' : null;
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  static String? newPassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty || value.length < minLength) {
      return 'Use at least $minLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != password) return "Passwords don't match";
    return null;
  }

  static String? phPhone(String? value, {bool required = false}) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return required ? 'Enter your phone number' : null;
    if (!_phMobile.hasMatch(digits)) return 'Enter a valid phone number';
    return null;
  }
}
