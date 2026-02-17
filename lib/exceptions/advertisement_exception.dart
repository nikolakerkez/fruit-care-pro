/// Custom exceptions for AdvertisementService operations
library;

/// Base exception class for all advertisement related errors
class AdvertisementException implements Exception {
  final String message;

  const AdvertisementException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when adding a category fails
class AddCategoryException extends AdvertisementException {
  const AddCategoryException(super.message);
}

/// Exception thrown when updating a category fails
class UpdateCategoryException extends AdvertisementException {
  const UpdateCategoryException(super.message);
}

/// Exception thrown when deleting a category fails
class DeleteCategoryException extends AdvertisementException {
  const DeleteCategoryException(super.message);
}

/// Exception thrown when retrieving categories fails
class GetCategoriesException extends AdvertisementException {
  const GetCategoriesException(super.message);
}

/// Exception thrown when adding an advertisement fails
class AddAdvertisementException extends AdvertisementException {
  const AddAdvertisementException(super.message);
}

/// Exception thrown when updating an advertisement fails
class UpdateAdvertisementException extends AdvertisementException {
  const UpdateAdvertisementException(super.message);
}

/// Exception thrown when deleting an advertisement fails
class DeleteAdvertisementException extends AdvertisementException {
  const DeleteAdvertisementException(super.message);
}

/// Exception thrown when retrieving advertisements fails
class GetAdvertisementsException extends AdvertisementException {
  const GetAdvertisementsException(super.message);
}