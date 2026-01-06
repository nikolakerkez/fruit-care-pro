class LoginException implements Exception {
  final String message;
  final String? code;

  LoginException(this.message, {this.code});

  @override
  String toString() => message;
}
