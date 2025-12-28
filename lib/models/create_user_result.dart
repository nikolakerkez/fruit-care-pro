
class CreateUserResult {
  final bool isFailed;
  final bool notUniqueUsername;
  final String? id;

  CreateUserResult(
      {this.id, required this.isFailed, required this.notUniqueUsername});
}
