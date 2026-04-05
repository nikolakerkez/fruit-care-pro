import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fruit_care_pro/exceptions/fruit_types_exception.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';

class FruitTypesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names as constants
  static const String _fruitTypesCollection = 'fruit_types';
  static const String _chatsCollection = 'chats';
  static const String _userFruitTypesCollection = 'user_2_fruittypes';
  static const String _membersSubcollection = 'members';

  /// Retrieves all fruit types as a stream
  /// Returns empty list if error occurs
  Stream<List<FruitType>> retrieveAllFruitTypes() {
    try {
      return _db.collection(_fruitTypesCollection).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            return FruitType.fromFirestore(data, doc.id);
          } catch (e, stackTrace) {
            ErrorLogger.logError(
              e,
              stackTrace,
              reason: 'Failed to parse fruit type document',
              screen: 'FruitTypesService.retrieveAllFruitTypes',
              additionalData: {
                'document_id': doc.id,
              },
            );
            // Skip this document and continue with others
            return null;
          }
        }).whereType<FruitType>().toList(); // Filter out nulls
      });
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to create fruit types stream',
        screen: 'FruitTypesService.retrieveAllFruitTypes',
      );
      return Stream.value([]);
    }
  }

  /// Deletes a fruit type and all related data (user associations, chat)
  /// Throws DeleteFruitTypeException if operation fails
  Future<void> deleteFruitType(String fruitTypeId) async {
    try {
      // Validate input
      if (fruitTypeId.isEmpty) {
        await ErrorLogger.logMessage(
          'deleteFruitType called with empty fruitTypeId',
        );
        throw const DeleteFruitTypeException('ID voćne vrste ne može biti prazan');
      }

      debugPrint('🗑️ Deleting fruit type: $fruitTypeId');

      // Fetch user associations outside the transaction (non-transactional read)
      final userQuery = await _db
          .collection(_userFruitTypesCollection)
          .where('fruitId', isEqualTo: fruitTypeId)
          .get();

      debugPrint('Found ${userQuery.docs.length} user associations to delete');

      await _db.runTransaction((transaction) async {
        final fruitRef = _db.collection(_fruitTypesCollection).doc(fruitTypeId);
        final chatRef = _db.collection(_chatsCollection).doc(fruitTypeId);

        // All reads first
        final fruitDoc = await transaction.get(fruitRef);
        final chatDoc = await transaction.get(chatRef);

        if (!fruitDoc.exists) {
          throw const DeleteFruitTypeException('Voćna vrsta ne postoji');
        }

        // Then writes
        for (var doc in userQuery.docs) {
          transaction.delete(doc.reference);
        }

        if (chatDoc.exists) {
          transaction.delete(chatRef);
          debugPrint('Deleted associated chat: $fruitTypeId');
        }

        transaction.delete(fruitRef);
      });

      debugPrint('✅ Successfully deleted fruit type: $fruitTypeId');
    } on DeleteFruitTypeException {
      rethrow; // Re-throw our custom exceptions
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to delete fruit type - Firestore error',
        screen: 'FruitTypesService.deleteFruitType',
        additionalData: {
          'fruit_type_id': fruitTypeId,
          'error_code': e.code,
        },
      );
      throw DeleteFruitTypeException(
        'Greška pri brisanju voćne vrste: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete fruit type - unexpected error',
        screen: 'FruitTypesService.deleteFruitType',
        additionalData: {
          'fruit_type_id': fruitTypeId,
        },
      );
      throw const DeleteFruitTypeException(
        'Neočekivana greška pri brisanju voćne vrste',
      );
    }
  }

  /// Adds a new fruit type and creates associated group chat
  /// Returns the ID of the newly created fruit type
  /// Throws AddFruitTypeException if operation fails
  Future<String> addFruitType(FruitType ft, String adminId) async {
    try {
      // Validate inputs
      if (ft.name.isEmpty) {
        await ErrorLogger.logMessage(
          'addFruitType called with empty fruit type name',
        );
        throw const AddFruitTypeException('Ime voćne vrste ne može biti prazno');
      }

      if (adminId.isEmpty) {
        await ErrorLogger.logMessage(
          'addFruitType called with empty adminId',
        );
        throw const AddFruitTypeException('Admin ID ne može biti prazan');
      }

      debugPrint('➕ Adding new fruit type: ${ft.name}');

      String fruitTypeId = '';

      await _db.runTransaction((transaction) async {
        // Generate new ID
        fruitTypeId = _db.collection(_fruitTypesCollection).doc().id;
        ft.id = fruitTypeId;

        // Create fruit type document
        final fruitTypesRef = _db.collection(_fruitTypesCollection).doc(fruitTypeId);
        transaction.set(fruitTypesRef, {
          'name': ft.name,
          'numberOfTreesPerAre': ft.numberOfTreesPerAre,
        });

        // Create associated group chat
        final fruitTypeChatRef = _db.collection(_chatsCollection).doc(fruitTypeId);
        transaction.set(fruitTypeChatRef, {
          'type': 'group',
          'name': ft.name,
          'lastMessage': {
            'text': '',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': '',
            'readBy': {},
          },
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'members': [],
          'memberIds': [adminId],
        });

        // Add admin as first member of the chat
        final memberRef = _db
            .collection(_chatsCollection)
            .doc(fruitTypeId)
            .collection(_membersSubcollection)
            .doc(adminId);

        transaction.set(
          memberRef,
          {
            'userId': adminId,
            'lastMessage': {
              'message': '-',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            },
            'memberSince': FieldValue.serverTimestamp(),
            'messagesVisibleFrom': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      debugPrint('✅ Successfully added fruit type: $fruitTypeId');
      return fruitTypeId;
    } on AddFruitTypeException {
      rethrow; // Re-throw our custom exceptions
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to add fruit type - Firestore error',
        screen: 'FruitTypesService.addFruitType',
        additionalData: {
          'fruit_type_name': ft.name,
          'admin_id': adminId,
          'error_code': e.code,
        },
      );
      throw AddFruitTypeException(
        'Greška pri dodavanju voćne vrste: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to add fruit type - unexpected error',
        screen: 'FruitTypesService.addFruitType',
        additionalData: {
          'fruit_type_name': ft.name,
          'admin_id': adminId,
        },
      );
      throw const AddFruitTypeException(
        'Neočekivana greška pri dodavanju voćne vrste',
      );
    }
  }

  /// Returns all users associated with a fruit type, with their tree counts
  Future<List<Map<String, dynamic>>> getUsersForFruitType(String fruitTypeId) async {
    try {
      final snap = await _db
          .collection(_userFruitTypesCollection)
          .where('fruitId', isEqualTo: fruitTypeId)
          .get();

      final result = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final numberOfTrees = data['numberOfTrees'] as int? ?? 0;

        if (userId == null) continue;

        final userDoc = await _db.collection('users').doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data();
        final name = userData?['name'] as String? ?? 'Nepoznat';
        final thumbUrl = userData?['thumbUrl'] as String?;
        result.add({
          'name': name,
          'numberOfTrees': numberOfTrees,
          'thumbUrl': thumbUrl,
        });
      }

      result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return result;
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to get users for fruit type',
        screen: 'FruitTypesService.getUsersForFruitType',
        additionalData: {'fruit_type_id': fruitTypeId},
      );
      return [];
    }
  }

  /// Updates an existing fruit type and its associated chat name
  /// Throws UpdateFruitTypeException if operation fails
  Future<void> updateFruitType(FruitType fruitType) async {
    try {
      // Validate inputs
      if (fruitType.id.isEmpty) {
        await ErrorLogger.logMessage(
          'updateFruitType called with empty fruit type ID',
        );
        throw const UpdateFruitTypeException('ID voćne vrste ne može biti prazan');
      }

      if (fruitType.name.isEmpty) {
        await ErrorLogger.logMessage(
          'updateFruitType called with empty fruit type name',
        );
        throw const UpdateFruitTypeException('Ime voćne vrste ne može biti prazno');
      }

      debugPrint('📝 Updating fruit type: ${fruitType.id}');

      await _db.runTransaction((transaction) async {
        final fruitTypeRef =
            _db.collection(_fruitTypesCollection).doc(fruitType.id);
        final fruitTypeChatRef =
            _db.collection(_chatsCollection).doc(fruitType.id);

        // All reads first
        final fruitDoc = await transaction.get(fruitTypeRef);
        final chatDoc = await transaction.get(fruitTypeChatRef);

        if (!fruitDoc.exists) {
          throw const UpdateFruitTypeException('Voćna vrsta ne postoji');
        }

        // Then writes
        transaction.update(fruitTypeRef, {
          'name': fruitType.name,
          'numberOfTreesPerAre': fruitType.numberOfTreesPerAre,
        });

        if (chatDoc.exists) {
          transaction.update(fruitTypeChatRef, {'name': fruitType.name});
          debugPrint('Updated associated chat name');
        } else {
          debugPrint('⚠️ No associated chat found for fruit type: ${fruitType.id}');
        }
      });

      debugPrint('✅ Successfully updated fruit type: ${fruitType.id}');
    } on UpdateFruitTypeException {
      rethrow; // Re-throw our custom exceptions
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to update fruit type - Firestore error',
        screen: 'FruitTypesService.updateFruitType',
        additionalData: {
          'fruit_type_id': fruitType.id,
          'fruit_type_name': fruitType.name,
          'error_code': e.code,
        },
      );
      throw UpdateFruitTypeException(
        'Greška pri ažuriranju voćne vrste: ${e.message ?? 'Nepoznata greška'}',
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to update fruit type - unexpected error',
        screen: 'FruitTypesService.updateFruitType',
        additionalData: {
          'fruit_type_id': fruitType.id,
          'fruit_type_name': fruitType.name,
        },
      );
      throw const UpdateFruitTypeException(
        'Neočekivana greška pri ažuriranju voćne vrste',
      );
    }
  }
}