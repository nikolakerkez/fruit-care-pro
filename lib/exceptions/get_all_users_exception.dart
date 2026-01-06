// lib/exceptions/user_service_exception.dart

class GetAllUsersException implements Exception {
  final String message;

  GetAllUsersException(this.message);

  @override
  String toString() => message;
}