
import 'dart:io';

import 'package:bb_agro_portal/services/documents_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {

final FirebaseFirestore _db = FirebaseFirestore.instance;

void sendMessage(String chatId, String senderId, String receiverId, String text, File? file) async {

  // Fetch chat for provided identifier
  var chatDoc = await _db.collection('chats').doc(chatId).get();

  if (!chatDoc.exists) {
    // If chat does not exist, create new
    await _createNewChat(chatId, senderId, receiverId);
  }
  
  if (file != null)
  {   
    await _sendImageToChat(chatId, senderId, file);
  }
  else
  {
  // Then the message is added to the chat
    await _sendMessageToChat(chatId, senderId, text);
  }
}

Future<void> createNewGroupChat(String chatId, String chatName, List<String> userIds) async
{
  try
  {
    List<Map<String, dynamic>> members = userIds.map((s) => {
      'userId': s,
      'memberSince': FieldValue.serverTimestamp(),
      'messagesVisibleFrom': FieldValue.serverTimestamp(),
    }).toList();

    await _db.collection('chats').doc(chatId).set({
        'type': 'group',
        'name': chatName,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'members': [],
        'memberIds' : []
      });
  }
  catch(e)
  {
    print('Error creating group chat: $e');
  }
}

Future<void> updateGroupChatName(String chatId, String chatName,) async {
    try {
      // Ažuriramo voćnu vrstu u kolekciji 'fruit_types' pomoću ID-a
      await _db.collection('chats').doc(chatId).update({
        'name': chatName
      });

      print("Voćna vrsta uspešno ažurirana.");
    } catch (e) {
      print("Greška prilikom uordated group chat name -ß $e");
    }
  }

  Future<void> addUserChat(String chatId, String userId) async {
    try {

        await _db.collection('chats')
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


        await FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .update({
                  'memberIds': FieldValue.arrayUnion([userId])});


    } catch (e) {

      print('Error during adding user to chat ' + e.toString());
    }
  }
Future<void> createNewPrivateChat(String chatId, String chatName) async
{
  try
  {


    await _db.collection('chats').doc(chatId).set({
        'type': 'private',
        'name': chatName,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'members': [],
        'memberIds' : []
      });
  }
  catch(e)
  {
    print('Error creating group chat: $e');
  }
}

Future<Map<String, String?>?> getChatTitlePrivateChat(
    DocumentSnapshot? chatDoc, String? currentUserId) async {
  if (chatDoc == null || currentUserId == null) return null;

  try {
    List<dynamic>? memberIds = chatDoc.get('memberIds');
    if (memberIds == null || memberIds.isEmpty) return null;

    String? otherUserId = memberIds
        .firstWhere((id) => id != currentUserId, orElse: () => null);

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
Future<void> _createNewChat(String chatId, String user1Id, String user2Id) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'isLastMessageRead': 0,
        'lastMessageSenderId' : '',
        'lastMessageReceiverId' : ''
      });
    } catch (e) {
      print('Error creating chat: $e');
    }
  }

Future<void> _sendMessageToChat(String chatId, String senderId, String messageText) async {
  try {
    print('Sending message...');

    // 1. Dodavanje nove poruke
    await _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'message': messageText,
      'imageUrl': null,
      'thumbUrl': null,
      'imagePath': null,
      'thumbPath': null,
      'timestamp': FieldValue.serverTimestamp(),
      'messageReadByUserIds': [senderId], // pošiljalac je odmah pročitao
    });

    // 2. Ažuriranje lastMessage po članu
    final membersSnapshot = await _db
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .get();

    for (var memberDoc in membersSnapshot.docs) {
      bool isSender = memberDoc['userId'] == senderId;

      await memberDoc.reference.update({
        'lastMessage': {
          'message': messageText,
          'timestamp': FieldValue.serverTimestamp(),
          'read': isSender, // sender je pročitao odmah, ostali ne
        }
      });
    }

    print('Message sent successfully.');

  } catch (e) {
    print('Error sending message: $e');
  }
}

Future<void> _sendImageToChat(String chatId, String senderId, File file) async {
  try {
      final messagesRef = FirebaseFirestore.instance.collection('chats/$chatId/messages');

      // 1️⃣ Generiši ID poruke odmah (da možeš posle da je update-uješ)
      final docRef = messagesRef.doc();

      // 2️⃣ Dodaj poruku odmah (privremeno, bez URL-a)
      await docRef.set({
        'id': docRef.id,
        'senderId': senderId,
        'imageUrl': null,
        'thumbUrl': null,
        'imagePath': null,
        'thumbPath': null,
        'localImagePath': file.path,
        'message': "",
        'isUploading': true,
        'timestamp': FieldValue.serverTimestamp(),
        'messageReadByUserIds': [senderId], 
      });

      Map<String, String>? uploadImageResult = await uploadImage(file, 'slika2');
      
      String? imagePath= uploadImageResult?["fullPath"];

      String? thumbPath = uploadImageResult?['thumbPath'];

      String? imageUrl = uploadImageResult?["fullUrl"];

      String? thumbUrl = uploadImageResult?['thumbUrl'];
      
      await docRef.update({
        'imageUrl': imageUrl,
        'thumbUrl': thumbUrl,
        'imagePath': imagePath,
        'thumbPath': thumbPath,
        'isUploading': false,
       });

      // 2. Ažuriranje lastMessage po članu
      final membersSnapshot = await _db
          .collection('chats')
          .doc(chatId)
          .collection('members')
          .get();

      for (var memberDoc in membersSnapshot.docs) {
        bool isSender = memberDoc['userId'] == senderId;

        await memberDoc.reference.update({
          'lastMessage': {
            'message': "-Fotografija-",
            'timestamp': FieldValue.serverTimestamp(),
            'read': isSender, // sender je pročitao odmah, ostali ne
          }
        });
    }

  } catch (e) {
    print('Error sending message: $e');
  }
}


Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
  try {
    // Dohvati chat dokument
    DocumentSnapshot chatDoc = await _db.collection('chats').doc(chatId).get();

    // Provera ako chat dokument postoji
    if (chatDoc.exists) {
      // Dohvati ko je poslednji primio poruku (receiverId poslednje poruke)
      String lastMessageReceiverId = chatDoc['lastMessageReceiverId'];

      // Ako trenutni korisnik nije poslednji receiver, nema potrebe za označavanjem
      if (lastMessageReceiverId != currentUserId) {
        print('Korisnik nije receiver poslednje poruke. Nema potrebe za označavanjem.');
        return;
      }

      // Dohvati vreme kada je poslednja poruka poslata
      Timestamp lastMessageTimestamp = chatDoc['lastMessageTimestamp'];

      // Dohvati sve poruke koje nisu označene kao pročitanne i koje su poslali korisnici pre poslednje poruke
      QuerySnapshot messagesSnapshot = await _db.collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('timestamp', isLessThanOrEqualTo: lastMessageTimestamp)
          .where('isRead', isEqualTo: false) // Samo nepročitane poruke
          .get();

      // Iteriranje kroz sve nepročitane poruke i označavanje kao pročitajne
      for (var messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.update({
          'isRead': true, // Oznaka da je poruka pročitana
        });
      }

      await _db.collection('chats').doc(chatId).update({
        'isLastMessageRead' : true
      });
      
      print('Sve nepročitane poruke su označene kao pročitajne.');
    } else {
      print('Chat sa id $chatId ne postoji.');
    }
  } catch (e) {
    print('Greška pri označavanju poruka kao pročitanih: $e');
  }
}


}

