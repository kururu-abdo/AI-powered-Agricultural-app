abstract final class AuthValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value, {required bool signingUp}) {
    // Passwords must never be trimmed or otherwise silently modified.
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (signingUp && value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }
}
