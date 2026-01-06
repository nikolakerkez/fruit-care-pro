// lib/exceptions/user_service_exception.dart

class GetAdminIdException implements Exception {
  final String message;

  GetAdminIdException(this.message);

  @override
  String toString() => message;
}