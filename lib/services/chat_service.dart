import 'dart:io';
import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/services/documents_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ChatItem>> getChatsStreamForUser(String userId) {
    debugPrint('🔵 Starting getAdminChatsStream for admin: $userId');

    return _db
        .collection('chats')
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snap) {
      debugPrint('🟢 Stream received ${snap.docs.length} chats');

      final chats = snap.docs.map((doc) {
        debugPrint('  - Chat: ${doc.id}');
        try {
          return ChatItem.fromFirestore(doc);
        } catch (e) {
          debugPrint('  ❌ Error parsing chat ${doc.id}: $e');
          rethrow;
        }
      }).toList();

      debugPrint('✅ Returning ${chats.length} chats');
      return chats;
    }).handleError((error) {
      debugPrint('🔴 Error in stream: $error');
      return <ChatItem>[];
    });
  }

  Future sendMessage(String chatId, String senderId, String receiverId,
      String text, File? file) async {
    // Fetch chat for provided identifier
    var chatDoc = await _db.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // If chat does not exist, create new
      await _createNewChat(chatId, senderId, receiverId);
    }

    if (file != null) {
      await sendImageToChat(
          chatId: chatId, senderId: senderId, imageFile: file);
    } else {
      // Then the message is added to the chat
      await sendMessageToChat(
          chatId: chatId, senderId: senderId, messageText: text);
    }
  }

  Future<void> createNewGroupChat(
      String chatId, String chatName, List<String> userIds) async {
    try {
      List<Map<String, dynamic>> members = userIds
          .map((s) => {
                'userId': s,
                'memberSince': FieldValue.serverTimestamp(),
                'messagesVisibleFrom': FieldValue.serverTimestamp(),
              })
          .toList();

      await _db.collection('chats').doc(chatId).set({
        'type': 'group',
        'name': chatName,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'members': [],
        'memberIds': []
      });
    } catch (e) {
      print('Error creating group chat: $e');
    }
  }

  Future<void> updateGroupChatName(
    String chatId,
    String chatName,
  ) async {
    try {
      // Ažuriramo voćnu vrstu u kolekciji 'fruit_types' pomoću ID-a
      await _db.collection('chats').doc(chatId).update({'name': chatName});

      print("Voćna vrsta uspešno ažurirana.");
    } catch (e) {
      print("Greška prilikom uordated group chat name -ß $e");
    }
  }

  Future<void> addUserChat(String chatId, String userId) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('members')
          .doc(userId) // dokument za tog usera
          .set({
        'userId': userId,
        'periods': [
          {
            'joinedAt': DateTime.now(),
            'leftAt': null,
          }
        ],
        'lastMessage': {
          'message': "-", // inicijalno prazno
          'timestamp': FieldValue.serverTimestamp(),
          'read': false, // inicijalno nije pročitao
        },
        'memberSince': FieldValue.serverTimestamp(),
        'messagesVisibleFrom': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'memberIds': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print('Error during adding user to chat ' + e.toString());
    }
  }

  Future<void> createNewPrivateChat(String chatId, String chatName) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'type': 'private',
        'name': chatName,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'members': [],
        'memberIds': []
      });
    } catch (e) {
      print('Error creating group chat: $e');
    }
  }

  Future<Map<String, String?>?> getChatTitlePrivateChat(
      DocumentSnapshot? chatDoc, String? currentUserId) async {
    if (chatDoc == null || currentUserId == null) return null;

    try {
      List<dynamic>? memberIds = chatDoc.get('memberIds');
      if (memberIds == null || memberIds.isEmpty) return null;

      String? otherUserId =
          memberIds.firstWhere((id) => id != currentUserId, orElse: () => null);

      if (otherUserId == null) return null;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      String? name;
      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        name = data?['name'];
      }

      return {
        "userId": otherUserId,
        "name": name ?? otherUserId,
      };
    } catch (e) {
      print("Greška u getChatTitlePrivateChat: $e");
      return null;
    }
  }

// If user and admin does not have already created chat (communication)
// this method will initialize their chat.
  Future<void> _createNewChat(
      String chatId, String user1Id, String user2Id) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'isLastMessageRead': 0,
        'lastMessageSenderId': '',
        'lastMessageReceiverId': ''
      });
    } catch (e) {
      print('Error creating chat: $e');
    }
  }

  Future<String> sendMessageToChat({
    required String chatId,
    required String senderId,
    required String messageText,
    String? imageUrl,
    String? thumbUrl,
  }) async {
    try {
      print('Sending message...');

      // 1. DOHVATI SVE ČLANOVE PRE TRANSACTION-A
      final membersSnapshot =
          await _db.collection('chats').doc(chatId).collection('members').get();

      final memberIds =
          membersSnapshot.docs.map((doc) => doc['userId'] as String).toList();

      // 2. SVE U JEDNOM TRANSACTION-U
      final messageId = await _db.runTransaction<String>((transaction) async {
        // Kreiraj referencu za poruku
        final messageRef =
            _db.collection('chats').doc(chatId).collection('messages').doc();

        final timestamp = Timestamp.now();
        final readByMap = {senderId: timestamp};

        // a) Dodaj poruku
        transaction.set(messageRef, {
          'senderId': senderId,
          'message': messageText,
          'imageUrl': imageUrl,
          'thumbUrl': thumbUrl,
          'timestamp': timestamp,
          'readBy': readByMap,
        });

        // b) Ažuriraj chat dokument
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

        // c) Ažuriraj SVE member dokumente
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

      print('Message sent successfully: $messageId');
      return messageId;
    } on FirebaseException catch (e) {
      print('Firebase error sending message: ${e.code} - ${e.message}');
      return "";
    } catch (e) {
      print('Unexpected error sending message: $e');
      return "";
    }
  }

  Future<String> sendImageToChat({
    required String chatId,
    required String senderId,
    required File imageFile,
  }) async {
    try {
      print('📤 Sending image message...');

      // 1. Dohvati chat podatke
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) throw Exception('Chat ne postoji');

      final chatData = chatDoc.data()!;
      final allMemberIds = List<String>.from(chatData['memberIds'] ?? []);

      // 2. Dohvati members
      final membersSnapshot =
          await _db.collection('chats').doc(chatId).collection('members').get();

      // 3. ODMAH kreiraj poruku sa placeholder-om
      final messageRef =
          _db.collection('chats').doc(chatId).collection('messages').doc();

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
          'localImagePath': imageFile.path, // 🔥 Local path za prikaz
          'timestamp': timestamp,
          'readBy': readByMap,
          'memberIds': allMemberIds,
          'isUploading': true,
          'uploadProgress': 0.0,
        });

        // Ažuriraj chat
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

        // Ažuriraj members
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

      print('✅ Placeholder message created: ${messageRef.id}');

      // 4. Upload SAMO THUMBNAIL prvo (brzo!)
      _uploadThumbnailFirst(
        messageRef: messageRef,
        chatId: chatId,
        senderId: senderId,
        imageFile: imageFile,
        membersSnapshot: membersSnapshot,
      );

      return messageRef.id;
    } catch (e) {
      print('❌ Error creating message: $e');
      return "";
    }
  }

// 🚀 NOVA strategija - upload thumb prvo, pa full kasnije
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

      // 1. Kompresuj SAMO thumbnail (brzo - <1 sekunda)
      print('🔄 Compressing thumbnail...');
      final thumbBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 200,
        quality: 70,
      );

      if (thumbBytes == null) {
        await messageRef.update({'isUploading': false, 'uploadFailed': true});
        return;
      }

      // 2. Upload SAMO thumbnail (brzo - 1-2 sekunde)
      print('⬆️ Uploading thumbnail...');
      final storage = FirebaseStorage.instance;
      final thumbRef = storage.ref('chat_images/$thumbName');

      final thumbTask = thumbRef.putData(
        thumbBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );

      // Track progress samo za thumbnail
      thumbTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        messageRef.update({'uploadProgress': progress * 0.5}); // 0-50%
      });

      await thumbTask;
      final thumbUrl = await thumbRef.getDownloadURL();

      print('✅ Thumbnail uploaded! Updating message...');

      // 3. ODMAH ažuriraj poruku sa thumbnail-om (korisnik vidi sliku!)
      await _db.runTransaction((transaction) async {
        transaction.update(messageRef, {
          'thumbUrl': thumbUrl,
          'thumbPath': thumbRef.fullPath,
          'uploadProgress': 0.5, // Thumbnail gotov
        });

        // Ažuriraj chat
        final chatRef = _db.collection('chats').doc(chatId);
        transaction.update(chatRef, {
          'lastMessage.text': '📷 Slika',
        });

        // Ažuriraj members
        for (var memberDoc in membersSnapshot.docs) {
          transaction.update(memberDoc.reference, {
            'lastMessage.message': '📷 Slika',
          });
        }
      });

      print('🎉 Thumbnail ready! Now uploading full image in background...');

      // 4. Upload FULL sliku u POZADINI (ne blokira UI)
      _uploadFullImageInBackground(
        messageRef: messageRef,
        imageFile: imageFile,
        fullName: fullName,
      );
    } catch (e) {
      print('❌ Thumbnail upload error: $e');
      await messageRef.update({
        'isUploading': false,
        'uploadFailed': true,
      });
    }
  }

// 🔄 Upload full slike u pozadini
  Future<void> _uploadFullImageInBackground({
    required DocumentReference messageRef,
    required File imageFile,
    required String fullName,
  }) async {
    try {
      print('🔄 Compressing full image...');
      final fullBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 800,
        quality: 85,
      );

      if (fullBytes == null) {
        print('⚠️ Full image compression failed, keeping thumbnail only');
        await messageRef.update({
          'isUploading': false,
          'uploadProgress': 1.0,
          'localImagePath': FieldValue.delete(), // ✅ Dodaj ovo
        });
        return;
      }

      print('⬆️ Uploading full image...');
      final storage = FirebaseStorage.instance;
      final fullRef = storage.ref('chat_images/$fullName');

      final fullTask = fullRef.putData(
        fullBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );

      // ❌ UKLONI progress tracking za full sliku - pravi previše update-a
      // thumbTask.snapshotEvents.listen((snapshot) {
      //   final progress = 0.5 + (snapshot.bytesTransferred / snapshot.totalBytes) * 0.5;
      //   messageRef.update({'uploadProgress': progress});
      // });

      await fullTask;
      final fullUrl = await fullRef.getDownloadURL();

      print('✅ Full image uploaded!');

      // ✅ JEDAN update sa svim podacima
      await messageRef.update({
        'imageUrl': fullUrl,
        'imagePath': fullRef.fullPath,
        'isUploading': false,
        'uploadProgress': 1.0,
        'localImagePath': FieldValue.delete(),
      });

      print('🎉 Full image complete!');
    } catch (e) {
      print('⚠️ Full image upload error (thumbnail still works): $e');
      await messageRef.update({
        'isUploading': false,
        'uploadProgress': 1.0,
        'localImagePath': FieldValue.delete(), // ✅ Dodaj ovo
      });
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      await markLastMessageAsRead(chatId, userId);

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

      final batch = _db.batch();
      int updateCount = 0;

      for (var doc in messages.docs) {
        final readBy = doc.data()['readBy'] as Map<String, dynamic>? ?? {};

        if (!readBy.containsKey(userId)) {
          batch.update(doc.reference, {
            'readBy.$userId': FieldValue.serverTimestamp(),
            'deliveredTo.$userId': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint('Marked $updateCount messages as read');
      }
    } on FirebaseException catch (e) {
    } catch (e) {}
  }

  Future<void> markLastMessageAsRead(String chatId, String userId) async {
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        throw Exception('Chat ne postoji');
      }

      final chatData = chatDoc.data()!;
      final lastMessage = chatData['lastMessage'] as Map<String, dynamic>?;

      if (lastMessage == null) {
        print('No lastMessage to mark as read');
        return;
      }

      final readBy = lastMessage['readBy'] as Map<String, dynamic>? ?? {};

      // Ako user već pročitao
      if (readBy.containsKey(userId)) {
        print('User already read lastMessage');
        return;
      }

      // Ažuriraj samo lastMessage.readBy
      await chatRef.update({
        'lastMessage.readBy.$userId': FieldValue.serverTimestamp(),
      });

      print('✅ Marked lastMessage as read');
    } on FirebaseException catch (e) {
      print('Firebase error: ${e.code} - ${e.message}');
    } catch (e) {
      print('Error: $e');
    }
  }

// 4. POZADINSKI UPLOAD SA PROGRESS TRACKING-OM
  Future<void> _uploadImageInBackground({
    required DocumentReference messageRef,
    required String chatId,
    required String senderId,
    required File imageFile,
    required QuerySnapshot membersSnapshot,
  }) async {
    try {
      // Upload sa progress tracking-om
      final uploadResult = await uploadImageWithProgress(
        imageFile,
        'chat_images',
        onProgress: (progress) {
          // Opciono - ažuriraj progress u real-time
          messageRef.update({'uploadProgress': progress});
        },
      );

      if (uploadResult == null) {
        // Upload failed - označi poruku kao failed
        await messageRef.update({
          'isUploading': false,
          'uploadFailed': true,
        });
        return;
      }

      // 5. AŽURIRAJ PORUKU SA PRAVIM URL-OVIMA
      await _db.runTransaction((transaction) async {
        transaction.update(messageRef, {
          'imageUrl': uploadResult['fullUrl'],
          'thumbUrl': uploadResult['thumbUrl'],
          'imagePath': uploadResult['fullPath'],
          'thumbPath': uploadResult['thumbPath'],
          'isUploading': false,
          'uploadProgress': 1.0,
        });

        // Ažuriraj chat
        final chatRef = _db.collection('chats').doc(chatId);
        transaction.update(chatRef, {
          'lastMessage.text': '📷 Slika',
        });

        // Ažuriraj members
        for (var memberDoc in membersSnapshot.docs) {
          transaction.update(memberDoc.reference, {
            'lastMessage.message': '📷 Slika',
          });
        }
      });

      print('Image uploaded successfully!');
    } catch (e) {
      print('Background upload failed: $e');
      // Označi poruku kao failed
      await messageRef.update({
        'isUploading': false,
        'uploadFailed': true,
      });
    }
  }
}
