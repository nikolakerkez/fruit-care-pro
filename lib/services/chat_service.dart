import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fruit_care_pro/exceptions/chat_exception.dart';
import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a stream of chats for a specific user
  /// Automatically updates when chats change in Firestore
  /// [userId] - ID of the user whose chats to retrieve
  /// Returns stream of [ChatItem] list, sorted by last message timestamp
  Stream<List<ChatItem>> getChatsStreamForUser(String userId) {
    try {
      // Validate input
      if (userId.isEmpty) {
        ErrorLogger.logMessage(
          'Warning: getChatsStreamForUser called with empty userId',
        );
        return Stream.value([]);
      }

      debugPrint('🔵 Starting chat stream for user: $userId');

      return _db
          .collection('chats')
          .where('memberIds', arrayContains: userId)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        debugPrint('🟢 Stream received ${snapshot.docs.length} chat documents');

        final chats = <ChatItem>[];
        final failedChatIds = <String>[];

        // Parse each chat document
        for (final doc in snapshot.docs) {
          try {
            final chat = ChatItem.fromFirestore(doc);
            chats.add(chat);
            debugPrint('  ✅ Parsed chat: ${doc.id} - ${chat.name ?? "Private"}');
          } catch (e, stackTrace) {
            // Log parsing error but continue with other chats
            failedChatIds.add(doc.id);

            ErrorLogger.logError(
              e,
              stackTrace,
              reason: 'Failed to parse chat document',
              screen: 'ChatService.getChatsStreamForUser',
              additionalData: {
                'chat_id': doc.id,
                'user_id': userId,
              },
            );

            debugPrint('  ❌ Failed to parse chat ${doc.id}: $e');
          }
        }

        // Log warning if some chats failed
        if (failedChatIds.isNotEmpty) {
          debugPrint(
            '⚠️ ${failedChatIds.length} chats failed to parse: ${failedChatIds.join(", ")}',
          );
        }

        debugPrint('✅ Returning ${chats.length} valid chats');
        return chats;
      }).handleError((error, stackTrace) {
        // Log stream errors
        ErrorLogger.logError(
          error,
          stackTrace,
          reason: 'Error in chat stream',
          screen: 'ChatService.getChatsStreamForUser',
          additionalData: {'user_id': userId},
        );

        debugPrint('🔴 Stream error: $error');

        // Propagate error to UI
        throw error;
      });
    } catch (e, stackTrace) {
      // Handle initialization errors
      ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to initialize chat stream',
        screen: 'ChatService.getChatsStreamForUser',
        additionalData: {'user_id': userId},
      );

      debugPrint('🔴 Failed to create stream: $e');

      return Stream.error(e, stackTrace);
    }
  }

  /// Sends a message (text or image) to a chat
  /// Creates chat if it doesn't exist
  Future<String> sendMessage(
    String chatId,
    String senderId,
    String receiverId,
    String text,
    File? file,
  ) async {
    try {
      // Validate inputs
      if (chatId.isEmpty || senderId.isEmpty) {
        throw SendMessageException('Chat ID and sender ID are required');
      }

      // Check if chat exists
      final chatDoc = await _db.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Fetchuj ime pošiljaoca za naziv chata (admin šalje korisniku)
        final senderDoc = await _db.collection('users').doc(senderId).get();
        final senderName = senderDoc.data()?['name'] as String? ?? 'Admin';
        await _createNewChat(chatId, senderId, receiverId, senderName);
      }

      // Send image or text message
      if (file != null) {
        return await sendImageToChat(
          chatId: chatId,
          senderId: senderId,
          imageFile: file,
        );
      } else {
        return await sendMessageToChat(
          chatId: chatId,
          senderId: senderId,
          messageText: text,
        );
      }
    } on SendMessageException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send message',
        screen: 'ChatService.sendMessage',
        additionalData: {
          'chat_id': chatId,
          'sender_id': senderId,
          'has_file': file != null,
        },
      );
      throw SendMessageException('Greška pri slanju poruke');
    }
  }

  /// Creates a new chat between two users
  Future<void> _createNewChat(
    String chatId,
    String user1Id,
    String user2Id,
    String senderName,
  ) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'memberIds': [user1Id, user2Id],
        'name': senderName,
        'lastMessage': {
          'text': '',
          'timestamp': FieldValue.serverTimestamp(),
          'senderId': '',
          'readBy': {},
        },
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'lastMessageReceiverId': '',
      });

      debugPrint('✅ Created new chat: $chatId');
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to create new chat',
        screen: 'ChatService._createNewChat',
        additionalData: {
          'chat_id': chatId,
          'user1_id': user1Id,
          'user2_id': user2Id,
        },
      );
      throw CreateChatException('Greška pri kreiranju chata: ${e.message}');
    }
  }

  /// Sends a text message to a chat
  Future<String> sendMessageToChat({
    required String chatId,
    required String senderId,
    required String messageText,
    String? imageUrl,
    String? thumbUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    try {
      debugPrint('📤 Sending text message to chat: $chatId');

      // Validate inputs
      if (chatId.isEmpty || senderId.isEmpty) {
        throw SendMessageException('Chat ID and sender ID are required');
      }

      if (messageText.isEmpty && imageUrl == null) {
        throw SendMessageException('Message text or image URL is required');
      }

      // Get all members before transaction
      final membersSnapshot = await _db
          .collection('chats')
          .doc(chatId)
          .collection('members')
          .get();

      // Execute everything in a single transaction
      final messageId = await _db.runTransaction<String>((transaction) async {
        // Create message reference
        final messageRef = _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc();

        final timestamp = Timestamp.now();
        final readByMap = {senderId: timestamp};

        // Add message
        transaction.set(messageRef, {
          'senderId': senderId,
          'message': messageText,
          'imageUrl': imageUrl,
          'thumbUrl': thumbUrl,
          'timestamp': timestamp,
          'readBy': readByMap,
          if (replyTo != null) 'replyTo': replyTo,
        });

        // Update chat document
        final chatRef = _db.collection('chats').doc(chatId);
        transaction.update(chatRef, {
          'lastMessage': {
            'text': messageText,
            'timestamp': timestamp,
            'senderId': senderId,
            'readBy': readByMap,
          },
          'lastMessageTimestamp': timestamp,
        });

        // Update all member documents
        for (var memberDoc in membersSnapshot.docs) {
          final userId = memberDoc['userId'] as String;
          final isSender = userId == senderId;

          transaction.update(memberDoc.reference, {
            'lastMessage': {
              'message': messageText,
              'timestamp': timestamp,
              'read': isSender,
            },
            'unreadCount': isSender ? 0 : FieldValue.increment(1),
          });
        }

        return messageRef.id;
      });

      debugPrint('✅ Message sent successfully: $messageId');
      return messageId;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to send text message - Firestore error',
        screen: 'ChatService.sendMessageToChat',
        additionalData: {
          'chat_id': chatId,
          'sender_id': senderId,
          'error_code': e.code,
        },
      );
      throw SendMessageException('Greška pri slanju poruke: ${e.message}');
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send text message - unexpected error',
        screen: 'ChatService.sendMessageToChat',
        additionalData: {
          'chat_id': chatId,
          'sender_id': senderId,
        },
      );
      throw SendMessageException('Neočekivana greška pri slanju poruke');
    }
  }

  /// Sends an image message to a chat
  /// Creates placeholder message immediately, then uploads image in background
  Future<String> sendImageToChat({
    required String chatId,
    required String senderId,
    required File imageFile,
  }) async {
    try {
      debugPrint('📤 Sending image message to chat: $chatId');

      // Validate inputs
      if (chatId.isEmpty || senderId.isEmpty) {
        throw SendMessageException('Chat ID and sender ID are required');
      }

      if (!imageFile.existsSync()) {
        throw SendMessageException('Image file does not exist');
      }

      // Get chat data
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        throw SendMessageException('Chat not found');
      }

      final chatData = chatDoc.data()!;
      final allMemberIds = List<String>.from(chatData['memberIds'] ?? []);

      // Get members
      final membersSnapshot = await _db
          .collection('chats')
          .doc(chatId)
          .collection('members')
          .get();

      // Create placeholder message immediately
      final messageRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final timestamp = Timestamp.now();
      final readByMap = {senderId: timestamp};

      await _db.runTransaction((transaction) async {
        transaction.set(messageRef, {
          'messageId': messageRef.id,
          'senderId': senderId,
          'message': '',
          'imageUrl': null,
          'thumbUrl': null,
          'imagePath': null,
          'thumbPath': null,
          'localImagePath': imageFile.path,
          'timestamp': timestamp,
          'readBy': readByMap,
          'memberIds': allMemberIds,
          'isUploading': true,
          'uploadProgress': 0.0,
        });

        // Update chat
        final chatRef = _db.collection('chats').doc(chatId);
        transaction.update(chatRef, {
          'lastMessage': {
            'text': '📷 Slika se šalje...',
            'timestamp': timestamp,
            'senderId': senderId,
            'readBy': readByMap,
          },
          'lastMessageTimestamp': timestamp,
        });

        // Update members
        for (var memberDoc in membersSnapshot.docs) {
          final userId = memberDoc['userId'] as String;
          final isSender = userId == senderId;

          transaction.update(memberDoc.reference, {
            'lastMessage': {
              'message': '📷 Slika se šalje...',
              'timestamp': timestamp,
              'read': isSender,
            },
            'unreadCount': isSender ? 0 : FieldValue.increment(1),
            'lastActivity': timestamp,
          });
        }
      });

      debugPrint('✅ Placeholder message created: ${messageRef.id}');

      // Upload thumbnail first (fast), then full image in background
      _uploadThumbnailFirst(
        messageRef: messageRef,
        chatId: chatId,
        senderId: senderId,
        imageFile: imageFile,
        membersSnapshot: membersSnapshot,
      );

      return messageRef.id;
    } on SendMessageException {
      rethrow;
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to send image message - Firestore error',
        screen: 'ChatService.sendImageToChat',
        additionalData: {
          'chat_id': chatId,
          'sender_id': senderId,
          'error_code': e.code,
        },
      );
      throw SendMessageException('Greška pri slanju slike: ${e.message}');
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send image message - unexpected error',
        screen: 'ChatService.sendImageToChat',
        additionalData: {
          'chat_id': chatId,
          'sender_id': senderId,
        },
      );
      throw SendMessageException('Neočekivana greška pri slanju slike');
    }
  }

  /// Uploads thumbnail first for quick preview, then full image in background
  Future<void> _uploadThumbnailFirst({
    required DocumentReference messageRef,
    required String chatId,
    required String senderId,
    required File imageFile,
    required QuerySnapshot membersSnapshot,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbName = 'thumb_$timestamp.jpg';
      final fullName = 'full_$timestamp.jpg';

      // Compress thumbnail (fast - <1 second)
      debugPrint('🔄 Compressing thumbnail...');
      final thumbBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 200,
        quality: 70,
      );

      if (thumbBytes == null) {
        throw Exception('Failed to compress thumbnail');
      }

      // Upload thumbnail (fast - 1-2 seconds)
      debugPrint('⬆️ Uploading thumbnail...');
      final storage = FirebaseStorage.instance;
      final thumbRef = storage.ref('chat_images/$thumbName');

      final thumbTask = thumbRef.putData(
        thumbBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );

      // Track progress for thumbnail only
      final progressSub = thumbTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        messageRef.update({'uploadProgress': progress * 0.5}); // 0-50%
      });

      await thumbTask;
      await progressSub.cancel();
      final thumbUrl = await thumbRef.getDownloadURL();

      debugPrint('✅ Thumbnail uploaded! Updating message...');

      // Update message with thumbnail immediately
      await _db.runTransaction((transaction) async {
        transaction.update(messageRef, {
          'thumbUrl': thumbUrl,
          'thumbPath': thumbRef.fullPath,
          'uploadProgress': 0.5,
        });

        // Update chat
        final chatRef = _db.collection('chats').doc(chatId);
        transaction.update(chatRef, {
          'lastMessage.text': '📷 Slika',
        });

        // Update members
        for (var memberDoc in membersSnapshot.docs) {
          transaction.update(memberDoc.reference, {
            'lastMessage.message': '📷 Slika',
          });
        }
      });

      debugPrint('🎉 Thumbnail ready! Now uploading full image in background...');

      // Upload full image in background
      _uploadFullImageInBackground(
        messageRef: messageRef,
        imageFile: imageFile,
        fullName: fullName,
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Thumbnail upload failed',
        screen: 'ChatService._uploadThumbnailFirst',
      );

      debugPrint('❌ Thumbnail upload error: $e');
      
      await messageRef.update({
        'isUploading': false,
        'uploadFailed': true,
      });
    }
  }

  /// Uploads full image in background (non-blocking)
  Future<void> _uploadFullImageInBackground({
    required DocumentReference messageRef,
    required File imageFile,
    required String fullName,
  }) async {
    try {
      debugPrint('🔄 Compressing full image...');
      final fullBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 800,
        quality: 85,
      );

      if (fullBytes == null) {
        debugPrint('⚠️ Full image compression failed, keeping thumbnail only');
        await messageRef.update({
          'isUploading': false,
          'uploadProgress': 1.0,
          'localImagePath': FieldValue.delete(),
        });
        return;
      }

      debugPrint('⬆️ Uploading full image...');
      final storage = FirebaseStorage.instance;
      final fullRef = storage.ref('chat_images/$fullName');

      final fullTask = fullRef.putData(
        fullBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );

      await fullTask;
      final fullUrl = await fullRef.getDownloadURL();

      debugPrint('✅ Full image uploaded!');

      // Update message with full image URL
      await messageRef.update({
        'imageUrl': fullUrl,
        'imagePath': fullRef.fullPath,
        'isUploading': false,
        'uploadProgress': 1.0,
        'localImagePath': FieldValue.delete(),
      });

      debugPrint('🎉 Full image complete!');
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Full image upload failed (thumbnail still works)',
        screen: 'ChatService._uploadFullImageInBackground',
      );

      debugPrint('⚠️ Full image upload error (thumbnail still works): $e');
      
      await messageRef.update({
        'isUploading': false,
        'uploadProgress': 1.0,
        'localImagePath': FieldValue.delete(),
      });
    }
  }

  /// Marks all unread messages in a chat as read for a specific user
  /// Updates both individual messages and last message read status
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Validate inputs
      if (chatId.isEmpty || userId.isEmpty) {
        await ErrorLogger.logMessage(
          'markMessagesAsRead called with empty chatId or userId',
        );
        return;
      }

      // Mark last message as read in chat document
      await markLastMessageAsRead(chatId, userId);

      // Get all unread messages (messages not sent by this user)
      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .get();

      if (messages.docs.isEmpty) {
        debugPrint('No unread messages found for user $userId in chat $chatId');
        return;
      }

      // Batch update messages
      final batch = _db.batch();
      int updateCount = 0;

      for (var doc in messages.docs) {
        final data = doc.data();
        final readBy = data['readBy'] as Map<String, dynamic>? ?? {};

        // Only update if user hasn't read this message yet
        if (!readBy.containsKey(userId)) {
          batch.update(doc.reference, {
            'readBy.$userId': FieldValue.serverTimestamp(),
            'deliveredTo.$userId': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      // Commit batch if there are updates
      if (updateCount > 0) {
        await batch.commit();
        debugPrint('✅ Marked $updateCount messages as read in chat $chatId');
      } else {
        debugPrint('No messages to mark as read in chat $chatId');
      }
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to mark messages as read - Firestore error',
        screen: 'ChatService.markMessagesAsRead',
        additionalData: {
          'chat_id': chatId,
          'user_id': userId,
          'error_code': e.code,
        },
      );
      // Don't throw - this is non-critical, chat can continue
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to mark messages as read - unexpected error',
        screen: 'ChatService.markMessagesAsRead',
        additionalData: {
          'chat_id': chatId,
          'user_id': userId,
        },
      );
      // Don't throw - this is non-critical
    }
  }

  /// Marks the last message in a chat as read for a specific user
  /// Updates the readBy field in the chat document's lastMessage
  Future<void> markLastMessageAsRead(String chatId, String userId) async {
    try {
      // Validate inputs
      if (chatId.isEmpty || userId.isEmpty) {
        await ErrorLogger.logMessage(
          'markLastMessageAsRead called with empty chatId or userId',
        );
        return;
      }

      // Get chat document
      final chatRef = _db.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      // Check if chat exists
      if (!chatDoc.exists) {
        await ErrorLogger.logMessage('Chat document not found: $chatId');
        return;
      }

      // Get chat data
      final chatData = chatDoc.data();
      if (chatData == null) {
        await ErrorLogger.logMessage('Chat data is null for chat: $chatId');
        return;
      }

      // Get last message
      final lastMessage = chatData['lastMessage'] as Map<String, dynamic>?;

      if (lastMessage == null) {
        debugPrint('No lastMessage to mark as read in chat $chatId');
        return;
      }

      // Check if user already read the message
      final readBy = lastMessage['readBy'] as Map<String, dynamic>? ?? {};

      if (readBy.containsKey(userId)) {
        debugPrint('User $userId already read lastMessage in chat $chatId');
        return;
      }

      // Update lastMessage.readBy
      await chatRef.update({
        'lastMessage.readBy.$userId': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Marked lastMessage as read for user $userId in chat $chatId');
    } on FirebaseException catch (e) {
      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Failed to mark last message as read - Firestore error',
        screen: 'ChatService.markLastMessageAsRead',
        additionalData: {
          'chat_id': chatId,
          'user_id': userId,
          'error_code': e.code,
        },
      );
      // Don't throw - this is non-critical
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to mark last message as read - unexpected error',
        screen: 'ChatService.markLastMessageAsRead',
        additionalData: {
          'chat_id': chatId,
          'user_id': userId,
        },
      );
      // Don't throw - this is non-critical
    }
  }

  /// Izmeni tekst već poslate poruke (samo tekstualne poruke, samo pošiljalac
  /// sme ovo da radi - proveru dozvole radi UI pre poziva)
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    try {
      if (chatId.isEmpty || messageId.isEmpty) {
        throw SendMessageException('Chat ID i message ID su obavezni');
      }

      final trimmed = newText.trim();
      if (trimmed.isEmpty) {
        throw SendMessageException('Poruka ne može biti prazna');
      }

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'message': trimmed,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      await _updateChatPreviewIfLastMessage(
        chatId: chatId,
        messageId: messageId,
        newText: trimmed,
      );

      debugPrint('✅ Message edited: $messageId');
    } on SendMessageException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to edit message',
        screen: 'ChatService.editMessage',
        additionalData: {'chat_id': chatId, 'message_id': messageId},
      );
      throw SendMessageException('Greška pri izmeni poruke');
    }
  }

  /// Obriši poruku za sve učesnike chata (sadržaj se zamenjuje placeholderom).
  /// Dozvolu (samo pošiljalac) proverava UI pre poziva.
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    try {
      if (chatId.isEmpty || messageId.isEmpty) {
        throw SendMessageException('Chat ID i message ID su obavezni');
      }

      final messageRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      // Obriši i fajlove sa Storage-a (ako poruka ima sliku) da ne ostanu
      // "siročad" koji zauzimaju prostor
      final messageSnapshot = await messageRef.get();
      final messageData = messageSnapshot.data();
      final imagePath = messageData?['imagePath'] as String?;
      final thumbPath = messageData?['thumbPath'] as String?;

      if (imagePath != null || thumbPath != null) {
        final storage = FirebaseStorage.instance;
        await Future.wait([
          if (imagePath != null)
            storage.ref(imagePath).delete().catchError((e) {
              debugPrint('⚠️ Failed to delete full image from storage: $e');
            }),
          if (thumbPath != null)
            storage.ref(thumbPath).delete().catchError((e) {
              debugPrint('⚠️ Failed to delete thumbnail from storage: $e');
            }),
        ]);
      }

      await messageRef.update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'message': '',
        'imageUrl': null,
        'thumbUrl': null,
        'imagePath': null,
        'thumbPath': null,
        'replyTo': FieldValue.delete(),
      });

      await _updateChatPreviewIfLastMessage(
        chatId: chatId,
        messageId: messageId,
        newText: '🚫 Poruka je obrisana',
      );

      debugPrint('✅ Message deleted for everyone: $messageId');
    } on SendMessageException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete message for everyone',
        screen: 'ChatService.deleteMessageForEveryone',
        additionalData: {'chat_id': chatId, 'message_id': messageId},
      );
      throw SendMessageException('Greška pri brisanju poruke');
    }
  }

  /// Sakrij poruku samo za trenutnog korisnika (ostali učesnici je i dalje vide)
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      if (chatId.isEmpty || messageId.isEmpty || userId.isEmpty) {
        throw SendMessageException(
          'Chat ID, message ID i user ID su obavezni',
        );
      }

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'hiddenFor': FieldValue.arrayUnion([userId]),
      });

      debugPrint('✅ Message hidden for user $userId: $messageId');
    } on SendMessageException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete message for me',
        screen: 'ChatService.deleteMessageForMe',
        additionalData: {
          'chat_id': chatId,
          'message_id': messageId,
          'user_id': userId,
        },
      );
      throw SendMessageException('Greška pri brisanju poruke');
    }
  }

  /// Ako je izmenjena/obrisana poruka trenutno "lastMessage" u chat dokumentu,
  /// ažuriraj i taj preview tekst (koji se prikazuje u listi četova) da ne
  /// ostane zastareo. Poredi se po timestamp-u jer lastMessage ne čuva ID
  /// poruke. Ne baca grešku dalje - ovo je samo kozmetička sinhronizacija,
  /// glavna operacija (edit/delete) je već upisana.
  Future<void> _updateChatPreviewIfLastMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      final lastMessage = chatDoc.data()?['lastMessage'] as Map<String, dynamic>?;
      final lastTimestamp = lastMessage?['timestamp'] as Timestamp?;
      if (lastTimestamp == null) return;

      final messageDoc = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();
      final messageTimestamp = messageDoc.data()?['timestamp'] as Timestamp?;

      if (messageTimestamp != null && messageTimestamp == lastTimestamp) {
        await chatRef.update({'lastMessage.text': newText});
        debugPrint('✅ Chat list preview synced for chat: $chatId');
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to sync chat list preview after edit/delete',
        screen: 'ChatService._updateChatPreviewIfLastMessage',
        additionalData: {'chat_id': chatId, 'message_id': messageId},
      );
      // Non-critical - ne prekidaj glavnu operaciju zbog ovoga
    }
  }

  /// Postavi/skloni "kuca..." status za korisnika u chatu (privremeno polje
  /// na chat dokumentu). Nekritično - ne sme da ruši chat funkcionalnost.
  Future<void> setTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    if (chatId.isEmpty || userId.isEmpty) return;
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      if (isTyping) {
        await chatRef.update({'typing.$userId': FieldValue.serverTimestamp()});
      } else {
        await chatRef.update({'typing.$userId': FieldValue.delete()});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update typing status: $e');
    }
  }

  /// Stream izmena na chat dokumentu (koristi se za typing indikator)
  Stream<Map<String, dynamic>> watchChatDoc(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.data() ?? <String, dynamic>{});
  }

  /// Pretraži poruke u chatu koje sadrže dati tekst (case-insensitive).
  /// Firestore nema native full-text search, pa se filtrira na klijentu
  /// nad poslednjih [limit] poruka (dovoljno za realnu veličinu chata).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchMessages({
    required String chatId,
    required String query,
    int limit = 500,
  }) async {
    try {
      if (chatId.isEmpty || query.trim().isEmpty) return [];

      final snapshot = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final lowerQuery = query.trim().toLowerCase();

      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['isDeleted'] == true) return false;
        final text = (data['message'] as String?)?.toLowerCase() ?? '';
        return text.contains(lowerQuery);
      }).toList();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to search messages',
        screen: 'ChatService.searchMessages',
        additionalData: {'chat_id': chatId},
      );
      return [];
    }
  }
}