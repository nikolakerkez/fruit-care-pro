// lib/exceptions/wrong_password_exception.dart

class WrongPasswordException implements Exception {
  final String message;

  WrongPasswordException(this.message);

  @override
  String toString() => message;
}