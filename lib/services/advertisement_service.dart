import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fruit_care_pro/exceptions/advertisement_exception.dart';
import 'package:fruit_care_pro/models/advertisement.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';

class AdvertisementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names as constants
  static const String _categoriesCollection = 'advertisement_categories';
  static const String _advertisementsCollection = 'advertisements';

  /// Retrieves all advertisement categories as a stream
  /// Returns empty list if error occurs
  Stream<List<AdvertisementCategory>> retrieveAllCategories() {
    try {
      return _db.collection(_categoriesCollection).snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                return AdvertisementCategory.fromFirestore(data, doc.id, 5);
              } catch (e, stackTrace) {
                ErrorLogger.logError(
                  e,
                  stackTrace,
                  reason: 'Failed to parse advertisement category document',
                  screen: 'AdvertisementService.retrieveAllCategories',
                  additionalData: {
                    'document_id': doc.id,
                  },
                );
                // Skip this document and continue with others
                return null;
              }
            })
            .whereType<AdvertisementCategory>()
            .toList(); // Filter out nulls
      });
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to create categories stream',
        screen: 'AdvertisementService.retrieveAllCategories',
      );
      return Stream.value([]);
    }
  }

  /// Adds a new advertisement category
  /// Returns the ID of the newly created category
  /// Throws AddCategoryException if operation fails
  Future<String> addCategory(AdvertisementCategory category) async {
    try {
      // Validate input
      if (category.name.isEmpty) {
        await ErrorLogger.logMessage(
          'addCategory called with empty category name',
        );
        throw const AddCategoryException(
            'Naziv kategorije ne može biti prazan');
      }

      debugPrint('➕ Adding new category: ${category.name}');

      final docRef = await _db.collection(_categoriesCollection).add({
        'name': category.name,
      });

      debugPrint('✅ Successfully added category with ID: ${docRef.id}');
      return docRef.id;
    } on AddCategoryException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to add category - Firestore error',
        screen: 'AdvertisementService.addCategory',
        additionalData: {
          'category_name': category.name,
          'error_code': e.code,
        },
      );
      throw AddCategoryException(
        'Greška pri dodavanju kategorije: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to add category - unexpected error',
        screen: 'AdvertisementService.addCategory',
        additionalData: {
          'category_name': category.name,
        },
      );
      throw const AddCategoryException(
        'Neočekivana greška pri dodavanju kategorije',
      );
    }
  }

  /// Updates an existing advertisement category
  /// Throws UpdateCategoryException if operation fails
  Future<void> updateCategory(AdvertisementCategory category) async {
    try {
      // Validate inputs
      if (category.id.isEmpty) {
        await ErrorLogger.logMessage(
          'updateCategory called with empty category ID',
        );
        throw const UpdateCategoryException(
            'ID kategorije ne može biti prazan');
      }

      if (category.name.isEmpty) {
        await ErrorLogger.logMessage(
          'updateCategory called with empty category name',
        );
        throw const UpdateCategoryException(
            'Naziv kategorije ne može biti prazan');
      }

      debugPrint('📝 Updating category: ${category.id}');

      // Check if category exists
      final docSnapshot =
          await _db.collection(_categoriesCollection).doc(category.id).get();

      if (!docSnapshot.exists) {
        throw const UpdateCategoryException('Kategorija ne postoji');
      }

      await _db.collection(_categoriesCollection).doc(category.id).update({
        'name': category.name,
      });

      debugPrint('✅ Successfully updated category: ${category.id}');
    } on UpdateCategoryException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to update category - Firestore error',
        screen: 'AdvertisementService.updateCategory',
        additionalData: {
          'category_id': category.id,
          'category_name': category.name,
          'error_code': e.code,
        },
      );
      throw UpdateCategoryException(
        'Greška pri ažuriranju kategorije: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to update category - unexpected error',
        screen: 'AdvertisementService.updateCategory',
        additionalData: {
          'category_id': category.id,
          'category_name': category.name,
        },
      );
      throw const UpdateCategoryException(
        'Neočekivana greška pri ažuriranju kategorije',
      );
    }
  }

  /// Deletes an advertisement category
  /// Throws DeleteCategoryException if operation fails
  Future<void> deleteCategory(String categoryId) async {
    try {
      // Validate input
      if (categoryId.isEmpty) {
        await ErrorLogger.logMessage(
          'deleteCategory called with empty categoryId',
        );
        throw const DeleteCategoryException(
            'ID kategorije ne može biti prazan');
      }

      debugPrint('🗑️ Deleting category: $categoryId');

      // Check if category exists
      final docSnapshot =
          await _db.collection(_categoriesCollection).doc(categoryId).get();

      if (!docSnapshot.exists) {
        throw const DeleteCategoryException('Kategorija ne postoji');
      }

      // Check if category has associated advertisements
      final adsSnapshot = await _db
          .collection(_advertisementsCollection)
          .where('categoryRefId', isEqualTo: categoryId)
          .limit(1)
          .get();

      if (adsSnapshot.docs.isNotEmpty) {
        throw const DeleteCategoryException(
          'Ne možete obrisati kategoriju koja ima reklame. Prvo obrišite sve reklame.',
        );
      }

      await _db.collection(_categoriesCollection).doc(categoryId).delete();

      debugPrint('✅ Successfully deleted category: $categoryId');
    } on DeleteCategoryException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to delete category - Firestore error',
        screen: 'AdvertisementService.deleteCategory',
        additionalData: {
          'category_id': categoryId,
          'error_code': e.code,
        },
      );
      throw DeleteCategoryException(
        'Greška pri brisanju kategorije: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete category - unexpected error',
        screen: 'AdvertisementService.deleteCategory',
        additionalData: {
          'category_id': categoryId,
        },
      );
      throw const DeleteCategoryException(
        'Neočekivana greška pri brisanju kategorije',
      );
    }
  }

  /// Adds a new advertisement
  /// Throws AddAdvertisementException if operation fails
  Future<String> addNewAdvertisement(Advertisement model) async {
    try {
      // Validate inputs
      if (model.name.isEmpty) {
        throw const AddAdvertisementException(
            'Naziv reklame ne može biti prazan');
      }

      if (model.categoryRefId.isEmpty) {
        throw const AddAdvertisementException('Kategorija je obavezna');
      }

      debugPrint('➕ Adding new advertisement: ${model.name}');

      String advertisementId = '';

      await _db.runTransaction((transaction) async {
        final docRef = _db.collection(_advertisementsCollection).doc();
        advertisementId = docRef.id;

        transaction.set(docRef, {
          'name': model.name,
          'description': model.description,
          'url': model.url,
          'imageUrl': model.imageUrl,
          'imagePath': model.imagePath,
          'thumbUrl': model.thumbUrl,
          'thumbPath': model.thumbPath,
          'localImagePath': model.localImagePath,
          'categoryRefId': model.categoryRefId,
        });
      });

      debugPrint(
          '✅ Successfully added advertisement with ID: $advertisementId');
      return advertisementId;
    } on AddAdvertisementException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to add advertisement - Firestore error',
        screen: 'AdvertisementService.addNewAdvertisement',
        additionalData: {
          'advertisement_name': model.name,
          'category_id': model.categoryRefId,
          'error_code': e.code,
        },
      );
      throw AddAdvertisementException(
        'Greška pri dodavanju reklame: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to add advertisement - unexpected error',
        screen: 'AdvertisementService.addNewAdvertisement',
        additionalData: {
          'advertisement_name': model.name,
          'category_id': model.categoryRefId,
        },
      );
      throw const AddAdvertisementException(
        'Neočekivana greška pri dodavanju reklame',
      );
    }
  }

  /// Updates an existing advertisement
  /// Throws UpdateAdvertisementException if operation fails
  Future<void> updateAdvertisement(Advertisement model) async {
    try {
      // Validate inputs
      if (model.id.isEmpty) {
        throw const UpdateAdvertisementException(
            'ID reklame ne može biti prazan');
      }

      if (model.name.isEmpty) {
        throw const UpdateAdvertisementException(
            'Naziv reklame ne može biti prazan');
      }

      debugPrint('📝 Updating advertisement: ${model.id}');

      // Check if advertisement exists
      final docSnapshot =
          await _db.collection(_advertisementsCollection).doc(model.id).get();

      if (!docSnapshot.exists) {
        throw const UpdateAdvertisementException('Reklama ne postoji');
      }

      await _db.collection(_advertisementsCollection).doc(model.id).update({
        'name': model.name,
        'description': model.description,
        'url': model.url,
        'imageUrl': model.imageUrl,
        'imagePath': model.imagePath,
        'thumbUrl': model.thumbUrl,
        'thumbPath': model.thumbPath,
        'localImagePath': model.localImagePath,
      });

      debugPrint('✅ Successfully updated advertisement: ${model.id}');
    } on UpdateAdvertisementException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to update advertisement - Firestore error',
        screen: 'AdvertisementService.updateAdvertisement',
        additionalData: {
          'advertisement_id': model.id,
          'advertisement_name': model.name,
          'error_code': e.code,
        },
      );
      throw UpdateAdvertisementException(
        'Greška pri ažuriranju reklame: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to update advertisement - unexpected error',
        screen: 'AdvertisementService.updateAdvertisement',
        additionalData: {
          'advertisement_id': model.id,
          'advertisement_name': model.name,
        },
      );
      throw const UpdateAdvertisementException(
        'Neočekivana greška pri ažuriranju reklame',
      );
    }
  }

  /// Deletes an advertisement
  /// Throws DeleteAdvertisementException if operation fails
  Future<void> deleteAdvertisement(String advertisementId) async {
    try {
      // Validate input
      if (advertisementId.isEmpty) {
        await ErrorLogger.logMessage(
          'deleteAdvertisement called with empty advertisementId',
        );
        throw const DeleteAdvertisementException(
            'ID reklame ne može biti prazan');
      }

      debugPrint('🗑️ Deleting advertisement: $advertisementId');

      // Check if advertisement exists
      final docSnapshot = await _db
          .collection(_advertisementsCollection)
          .doc(advertisementId)
          .get();

      if (!docSnapshot.exists) {
        throw const DeleteAdvertisementException('Reklama ne postoji');
      }

      // TODO: Optionally delete associated images from Firebase Storage
      // final data = docSnapshot.data();
      // if (data != null) {
      //   if (data['imagePath'] != null && data['imagePath'].isNotEmpty) {
      //     await DocumentsService().deleteImage(data['imagePath']);
      //   }
      //   if (data['thumbPath'] != null && data['thumbPath'].isNotEmpty) {
      //     await DocumentsService().deleteImage(data['thumbPath']);
      //   }
      // }

      await _db
          .collection(_advertisementsCollection)
          .doc(advertisementId)
          .delete();

      debugPrint('✅ Successfully deleted advertisement: $advertisementId');
    } on DeleteAdvertisementException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to delete advertisement - Firestore error',
        screen: 'AdvertisementService.deleteAdvertisement',
        additionalData: {
          'advertisement_id': advertisementId,
          'error_code': e.code,
        },
      );
      throw DeleteAdvertisementException(
        'Greška pri brisanju reklame: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete advertisement - unexpected error',
        screen: 'AdvertisementService.deleteAdvertisement',
        additionalData: {
          'advertisement_id': advertisementId,
        },
      );
      throw const DeleteAdvertisementException(
        'Neočekivana greška pri brisanju reklame',
      );
    }
  }

  /// Gets all advertisements for a specific category
  /// Throws GetAdvertisementsException if operation fails
  Future<List<Advertisement>> getAllAdvertisementsForCategory(
    String categoryId,
  ) async {
    try {
      // Validate input
      if (categoryId.isEmpty) {
        await ErrorLogger.logMessage(
          'getAllAdvertisementsForCategory called with empty categoryId',
        );
        throw const GetAdvertisementsException(
            'ID kategorije ne može biti prazan');
      }

      debugPrint('📋 Fetching advertisements for category: $categoryId');

      final querySnapshot = await _db
          .collection(_advertisementsCollection)
          .where('categoryRefId', isEqualTo: categoryId)
          .get();

      final advertisements = querySnapshot.docs.map((doc) {
        return Advertisement.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();

      debugPrint('✅ Found ${advertisements.length} advertisements');
      return advertisements;
    } on GetAdvertisementsException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to get advertisements - Firestore error',
        screen: 'AdvertisementService.getAllAdvertisementsForCategory',
        additionalData: {
          'category_id': categoryId,
          'error_code': e.code,
        },
      );
      throw GetAdvertisementsException(
        'Greška pri učitavanju reklama: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to get advertisements - unexpected error',
        screen: 'AdvertisementService.getAllAdvertisementsForCategory',
        additionalData: {
          'category_id': categoryId,
        },
      );
      throw const GetAdvertisementsException(
        'Neočekivana greška pri učitavanju reklama',
      );
    }
  }
}
