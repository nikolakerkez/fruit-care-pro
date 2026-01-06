// lib/exceptions/password_change_exception.dart

class PasswordChangeException implements Exception {
  final String message;

  PasswordChangeException(this.message);

  @override
  String toString() => message;
}