// lib/models/change_password_result.dart

class ChangePasswordResult {
  final bool isFailed;
  final bool isWrongPasswordProvided;

  ChangePasswordResult({
    required this.isFailed,
    required this.isWrongPasswordProvided,
  });

  // Factory constructors for common cases
  factory ChangePasswordResult.success() {
    return ChangePasswordResult(
      isFailed: false,
      isWrongPasswordProvided: false,
    );
  }

  factory ChangePasswordResult.wrongPassword() {
    return ChangePasswordResult(
      isFailed: true,
      isWrongPasswordProvided: true,
    );
  }

  factory ChangePasswordResult.failed() {
    return ChangePasswordResult(
      isFailed: true,
      isWrongPasswordProvided: false,
    );
  }

  bool get isSuccess => !isFailed && !isWrongPasswordProvided;
}