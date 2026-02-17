/// Custom exceptions for FruitTypesService operations
library;

/// Base exception class for all fruit type related errors
class FruitTypeException implements Exception {
  final String message;

  const FruitTypeException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when adding a fruit type fails
class AddFruitTypeException extends FruitTypeException {
  const AddFruitTypeException(super.message);
}

/// Exception thrown when updating a fruit type fails
class UpdateFruitTypeException extends FruitTypeException {
  const UpdateFruitTypeException(super.message);
}

/// Exception thrown when deleting a fruit type fails
class DeleteFruitTypeException extends FruitTypeException {
  const DeleteFruitTypeException(super.message);
}

/// Exception thrown when retrieving fruit types fails
class GetFruitTypesException extends FruitTypeException {
  const GetFruitTypesException(super.message);
}