import 'dart:io';
import 'package:fruit_care_pro/models/change_password_result.dart';
import 'package:fruit_care_pro/models/create_user_result.dart';
import 'package:fruit_care_pro/services/documents_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fruit_care_pro/models/create_user.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/models/user_fruit_type.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //Creates new user
  //1. In firebebase auth system
  //2. In database
  //3. Add external data like fruit types
  Future<CreateUserResult> createNewUser(CreateUserParam user) async {
    try {
      var userSnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        return CreateUserResult(isFailed: true, notUniqueUsername: true);
      }

      String? adminId = await getAdminId();
      if (adminId == null) {
        return CreateUserResult(isFailed: true, notUniqueUsername: false);
      }

      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
            email: user.email, password: user.password);

        if (userCredential.user == null) {
          return CreateUserResult(isFailed: true, notUniqueUsername: true);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return CreateUserResult(isFailed: true, notUniqueUsername: true);
        } else {
          return CreateUserResult(isFailed: true, notUniqueUsername: false);
        }
      }

      String userId = userCredential.user!.uid;
      String chatId = await generateChatId(userId, adminId);

      await _db.runTransaction((transaction) async {
        //User reference
        DocumentReference userRef =
            _db.collection('users').doc(userCredential.user!.uid);
        //Persist user
        transaction.set(userRef, {
          'email': user.email,
          'name': user.name,
          'isActive': false,
          'uid': userCredential.user!.uid,
          'city': user.city,
          'phone': user.phone,
          'isPasswordChangeNeeded': true
        });

        for (var ft in user.fruitTypes) {
          //UserFruitType Assignment Reference
          DocumentReference userFruitTypeRef =
              _db.collection('user_2_fruittypes').doc();
          //Persist new assignment
          transaction.set(userFruitTypeRef, {
            'userId': userCredential.user!.uid,
            'fruitId': ft.fruitTypeId,
            'numberOfTrees': ft.numberOfTrees
          });

          DocumentReference fruitTypeChatRef =
              _db.collection('chats').doc(ft.fruitTypeId);
          transaction.update(fruitTypeChatRef, {
            'memberIds': FieldValue.arrayUnion([userId]),
          });

          DocumentReference fruitTypeChatUserMemberRef = _db
              .collection('chats')
              .doc(ft.fruitTypeId)
              .collection('members')
              .doc(userId);
          transaction.set(
              fruitTypeChatUserMemberRef,
              {
                'userId': userId,
                'lastMessage': {
                  'message': "-", // inicijalno prazno
                  'timestamp': FieldValue.serverTimestamp(),
                  'read': false, // inicijalno nije pročitao
                },
                'memberSince': FieldValue.serverTimestamp(),
                'messagesVisibleFrom': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }

        //Add private chat
        DocumentReference privateChatRef = _db.collection('chats').doc(chatId);
        transaction.set(privateChatRef, {
          'type': 'private',
          'name': "Private chat",
          'lastMessage': {  // ✅ MORA biti objekat, NE string!
            'text': '',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': '',
            'readBy': {},
          },
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'members': [],
          'memberIds': [],  // ✅ Dodaj članove!
        });

        transaction.update(privateChatRef, {
          'memberIds': FieldValue.arrayUnion([userId, adminId]),
        });

        //Add admin member
        DocumentReference adminChatMemberRef = _db
            .collection('chats')
            .doc(chatId)
            .collection('members')
            .doc(adminId);
        transaction.set(
            adminChatMemberRef,
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

        //Add user member
        DocumentReference userChatMemberRef = _db
            .collection('chats')
            .doc(chatId)
            .collection('members')
            .doc(userId);
        transaction.set(
            userChatMemberRef,
            {
              'userId': userId,
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

      return CreateUserResult(
          isFailed: false,
          notUniqueUsername: false,
          id: userCredential.user!.uid);
    } catch (e) {
      return CreateUserResult(isFailed: true, notUniqueUsername: false);
    }
  }

  //Using this method user can change his password.
  Future<ChangePasswordResult> changePassword(
      String userId, String currentPassword, String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        return ChangePasswordResult(true, false);
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      UserCredential uc = await user.reauthenticateWithCredential(credential);
      if (uc.user == null) {
        return ChangePasswordResult(true, true);
      }

      await user.updatePassword(newPassword);

      await _db
          .collection('users')
          .doc(userId)
          .update({'isPasswordChangeNeeded': false});
      return ChangePasswordResult(false, false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        return ChangePasswordResult(true, true);
      }

      return ChangePasswordResult(true, false);
    } catch (e) {
      return ChangePasswordResult(true, false);
    }
  }

  //Rerieves all users
  Future<List<AppUser>> getAllUsers() async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('users').get();

      List<AppUser> users = querySnapshot.docs.map((doc) {
        return AppUser.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id, []);
      }).toList();

      return users;
    } catch (e) {
      return [];
    }
  }

  //Changes user type to be premium
  Future<bool> setPremiumFlag(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'isPremium': true});
      return true;
    } catch (e) {
      return false;
    }
  }

  //Changes user type to be standard/regular
  Future<bool> removePremiumFlag(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'isPremium': false});
      return true;
    } catch (e) {
      return false;
    }
  }

  //Mark user as active - can use system
  Future<bool> activateUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'isActive': true});

      return true;
    } catch (e) {
      return false;
    }
  }

  //Mark user as inactive - can not use system anymore
  Future<bool> deactivateUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({'isActive': false});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeUserData(CreateUserParam user) async {
    try {
      final userFruitRef = _db.collection('user_2_fruittypes');

      // Prvo dohvati sve veze korisnika → van transakcije
      final existingSnapshot =
          await userFruitRef.where('userId', isEqualTo: user!.id).get();

      await _db.runTransaction((transaction) async {
        // User ref from the firestore
        DocumentReference userRef = _db.collection('users').doc(user!.id);

        // Check if user already exists
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        transaction.set(userRef, {'city': user.city, 'phone': user.phone},
            SetOptions(merge: true));

        final userFruitRef = _db.collection('user_2_fruittypes');

        // Pretvori postojeće u mapu radi lakšeg poređenja
        final existingData = {
          for (var doc in existingSnapshot.docs)
            doc['fruitId']: {
              'docId': doc.id,
              'numberOfTrees': doc['numberOfTrees'],
            }
        };

        // 2. Prođi kroz nove voćne vrste
        for (var ft in user.fruitTypes) {
          if (existingData.containsKey(ft.fruitTypeId)) {
            // Postoji → proveri da li treba izmeniti broj stabala
            final existing = existingData[ft.fruitTypeId];
            if (existing!['numberOfTrees'] != ft.numberOfTrees) {
              transaction.update(
                userFruitRef.doc(existing['docId']),
                {'numberOfTrees': ft.numberOfTrees},
              );
            }
            // Ukloni iz mape — da znamo koje su ostale za brisanje
            existingData.remove(ft.fruitTypeId);
          } else {
            // Nova voćna vrsta → dodaj
            transaction.set(userFruitRef.doc(), {
              'userId': user.id,
              'fruitId': ft.fruitTypeId,
              'numberOfTrees': ft.numberOfTrees,
            });

            DocumentReference fruitTypeChatRef =
                _db.collection('chats').doc(ft.fruitTypeId);
            transaction.update(fruitTypeChatRef, {
              'memberIds': FieldValue.arrayUnion([user.id]),
            });

            DocumentReference fruitTypeChatUserMemberRef = _db
                .collection('chats')
                .doc(ft.fruitTypeId)
                .collection('members')
                .doc(user.id);
            transaction.set(
                fruitTypeChatUserMemberRef,
                {
                  'userId': user.id,
                  'lastMessage': {
                    'message': "-", // inicijalno prazno
                    'timestamp': FieldValue.serverTimestamp(),
                    'read': false, // inicijalno nije pročitao
                  },
                  'memberSince': FieldValue.serverTimestamp(),
                  'messagesVisibleFrom': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
          }
        }

        // 3. Sve što je ostalo u existingData znači da je obrisano
        for (var remaining in existingData.values) {
          transaction.delete(userFruitRef.doc(remaining['docId']));

          //what about chat
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<AppUser?> getUserById(String userId) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(userId).get();

    if (userDoc.exists) {
      return AppUser.fromFirestore(
          userDoc.data() as Map<String, dynamic>, userId, []);
    } else {
      return null;
    }
  }

  Future<AppUser?> getUserDetailsById(String userId) async {
    try {
      // 1. Dohvati podatke o korisniku
      final userDoc = await _db.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('User not found in Firestore.');
        return null;
      }

      final userData = userDoc.data()!;

      // 2. Dohvati sve veze user-fruittype
      final userFruitTypesSnap = await _db
          .collection('user_2_fruittypes')
          .where('userId', isEqualTo: userId)
          .get();

      // 3. Dohvati sve fruitType dokumente
      List<UserFruitType> fruitTypes = [];

      for (var doc in userFruitTypesSnap.docs) {
        final data = doc.data();
        final fruitTypeId = data['fruitId'];

        final fruitDoc =
            await _db.collection('fruit_types').doc(fruitTypeId).get();

        if (fruitDoc.exists) {
          final fruitData = fruitDoc.data();

          final fruitDataResult = UserFruitType.fromFirestore(
              data, fruitData as Map<String, dynamic>, fruitTypeId);
          fruitTypes.add(fruitDataResult);
        }
      }

      var userResult = AppUser.fromFirestore(
          userDoc.data() as Map<String, dynamic>, userId, fruitTypes);

      return userResult;
    } catch (e) {
      print('Error while getting user details: $e');
      return null;
    }
  }

  Future<AppUser?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.getIdToken(true);
        DocumentSnapshot userDoc =
            await _db.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          return AppUser.fromFirestore(
              userDoc.data() as Map<String, dynamic>, user.uid, []);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } on FirebaseAuthException {
      return null;
    }
  }

  // Funkcija za logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> getAdminId() async {
    try {
      var querySnapshot = await _db
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .limit(1) // Očekujemo samo jednog admina
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      } else {
        return null; // Nema admina
      }
    } catch (e) {
      print("Error getting admin ID: $e");
      return null;
    }
  }

  Future<void> updateUserProfileImage(String userId, File file) async {
    try {
      await _db.collection('users').doc(userId).update({
        'imageUrl': null,
        'thumbUrl': null,
        'imagePath': null,
        'thumbPath': null,
        'localImagePath': file.path,
      });

      Map<String, String>? uploadImageResult =
          await uploadImage(file, 'slika2');

      String? imagePath = uploadImageResult?["fullPath"];

      String? thumbPath = uploadImageResult?['thumbPath'];

      String? imageUrl = uploadImageResult?["fullUrl"];

      String? thumbUrl = uploadImageResult?['thumbUrl'];

      await _db.collection('users').doc(userId).update({
        'imageUrl': imageUrl,
        'thumbUrl': thumbUrl,
        'imagePath': imagePath,
        'thumbPath': thumbPath,
        'localImagePath': file.path,
      });
    } catch (e) {}
  }

  Future<String> generateChatId(String user1Id, String user2Id) async {
    String generatedChatId = '';
    if (user1Id.compareTo(user2Id) < 0) {
      generatedChatId = 'chat_${user1Id}_$user2Id';
    } else {
      generatedChatId = 'chat_${user2Id}_$user1Id';
    }

    return generatedChatId;
  }
}
