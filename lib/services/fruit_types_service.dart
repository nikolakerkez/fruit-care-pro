import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';

class FruitTypesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<FruitType>> retrieveAllFruitTypes() {
    try {
      return _db.collection('fruit_types').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          var data = doc.data();
          return FruitType.fromFirestore(data, doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  Future<bool> deleteFruitType(String fruitTypeId) async {
    try {
      await _db.runTransaction((transaction) async {
        final fruitRef = _db.collection("fruit_types").doc(fruitTypeId);

        final userQuery = await _db
            .collection("user_2_fruittypes")
            .where("fruitId", isEqualTo: fruitTypeId)
            .get();

        for (var doc in userQuery.docs) {
          transaction.delete(doc.reference);
        }

        final chatQuery = await _db
            .collection("chats")
            .where("id", isEqualTo: fruitTypeId)
            .get();

        for (var doc in chatQuery.docs) {
          transaction.delete(doc.reference);
        }
        transaction.delete(fruitRef);
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // // Metoda za dodavanje nove voćne vrste
  Future<String> addFruitType(FruitType ft, String adminId) async {
    try {
      await _db.runTransaction((transaction) async {

        ft.id = _db.collection('fruit_types').doc().id;

        DocumentReference fruitTypesRef =
            _db.collection('fruit_types').doc(ft.id);
        //Persist user
        transaction.set(fruitTypesRef, {
          'name': ft.name,
          'numberOfTreesPerAre': ft.numberOfTreesPerAre,
        });

        DocumentReference fruitTypeChatRef =
            _db.collection('chats').doc(ft.id);
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
          'memberIds' : [adminId]
        });

        DocumentReference fruitTypeChatUserMemberRef = _db
            .collection('chats')
            .doc(ft.id)
            .collection('members')
            .doc(adminId);

        transaction.set(
            fruitTypeChatUserMemberRef,
            {
              'userId': adminId,
              'lastMessage': {
                'message': "-", // inicijalno prazno
                'timestamp': FieldValue.serverTimestamp(),
                'read': false, // inicijalno nije pročitao
              },
              'memberSince': FieldValue.serverTimestamp(),
              'messagesVisibleFrom': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      return ft.id;
    } catch (e) {
      return "";
    }
  }

  // Metoda za ažuriranje voćne vrste u Firestore
  Future<bool> updateFruitType(FruitType fruitType) async {
    try {

      await _db.runTransaction((transaction) async {

      // Ažuriramo voćnu vrstu u kolekciji 'fruit_types' pomoću ID-a

      DocumentReference fruitTypeRef =
            _db.collection('fruit_types').doc(fruitType.id);

      transaction.update(fruitTypeRef, {
        'name': fruitType.name,
        'numberOfTreesPerAre': fruitType.numberOfTreesPerAre,
      });

      DocumentReference fruitTypeChatRef =
            _db.collection('chats').doc(fruitType.id);
        transaction.update(fruitTypeChatRef, {
          'name': fruitType.name
        });
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
