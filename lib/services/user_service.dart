import 'dart:io';

import 'package:bb_agro_portal/services/documents_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bb_agro_portal/models/create_user.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/models/user_fruit_type.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createNewUser(CreateUserParam user) async {
    print('Creating new user...');

    try {
      var userSnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        print("Email is already in use in Firestore.");
        return null;
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
              email: user.email, password: user.password);

      if (userCredential.user == null) {
        print('Failed to create user acoount.');
        return null;
      }

      await _db.runTransaction((transaction) async {
        // User ref from the firestore
        DocumentReference userRef =
            _db.collection('users').doc(userCredential.user!.uid);

        // Check if user already exists
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (userSnapshot.exists) {
          print('User already exists.');
          return;
        }

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
          transaction.set(_db.collection('user_2_fruittypes').doc(), {
            'userId': userCredential.user!.uid,
            'fruitId': ft.fruitTypeId,
            'numberOfTrees': ft.numberOfTrees
          });
        }

        print('User successfuly created.');
      });
    
      print('User added');
      print(userCredential.user!.uid);
      return userCredential.user!.uid;
    }
    
     on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('Auth exception, email address already in use.');
      } else {
        print('AuthException occured during creating of new user: $e');
      }
      return null;
    } catch (e) {
      print('Exception occured during creating of new user: $e');
    }
  }

Future<void> changeUserData(CreateUserParam user) async {
    print('Change user...');

    try {
      final userFruitRef = _db.collection('user_2_fruittypes');

      // Prvo dohvati sve veze korisnika → van transakcije
        final existingSnapshot = await userFruitRef
            .where('userId', isEqualTo: user!.id)
            .get();


      await _db.runTransaction((transaction) async {
        // User ref from the firestore
        DocumentReference userRef =
            _db.collection('users').doc(user!.id);

        // Check if user already exists
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        transaction.set(userRef, {
          'city': user.city,
          'phone': user.phone
        },
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
          }
        }

        // 3. Sve što je ostalo u existingData znači da je obrisano
        for (var remaining in existingData.values) {
          transaction.delete(userFruitRef.doc(remaining['docId']));
        }

        print('User successfuly created.');
      });
    }
    
     on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('Auth exception, email address already in use.');
      } else {
        print('AuthException occured during creating of new user: $e');
      }
      return null;
    } catch (e) {
      print('Exception occured during creating of new user: $e');
    }
  }


  Future<AppUser?> getUserById(String userId) async {
    
        DocumentSnapshot userDoc = await _db.collection('users').doc(userId).get();

        if (userDoc.exists) {
          return AppUser.fromFirestore(userDoc.data() as Map<String, dynamic>, userId, []);
        } else {
          return null;
        }
  }

  Future<List<AppUser>> getAllUsers() async {
  try {
    QuerySnapshot querySnapshot = await _db.collection('users').get();

    List<AppUser> users = querySnapshot.docs.map((doc) {
      return AppUser.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
        [], // ili ubaci fruitTypes ako trebaš ovde
      );
    }).toList();

    return users;
  } catch (e) {
    print('Greška prilikom dohvaćanja korisnika: $e');
    return [];
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

                final fruitDataResult = UserFruitType.fromFirestore(data, fruitData as Map<String, dynamic>, fruitTypeId);
                fruitTypes.add(fruitDataResult);
              }
            }

            var userResult = AppUser.fromFirestore(userDoc.data() as Map<String, dynamic>, userId, fruitTypes);

            return userResult;
          } catch (e) {
            print('Error while getting user details: $e');
            return null;
          }
}

  Future<AppUser?> login(String email, String password) async {
    try {

      print("Login started");
      print(email);
      print(password);
      // 1. Prijavi korisnika sa Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {

        print("User is found");
        // 2. Proveri da li je korisnik admin u Firestore-u
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          return AppUser.fromFirestore(userDoc.data() as Map<String, dynamic>, user.uid, []);
        } else {
          return null;
        }
      } else {
        print("User not found");
        return null;
      }
    } on FirebaseAuthException {
      // Ako je došlo do greške prilikom logovanja

      print("User is found exception");
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


Future<void> changePassword(String userId, String currentPassword, String newPassword) async {
  try {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("No authenticated user found.");
    }

    // 🔑 Korisnik mora ponovo da se autentifikuje pre promene lozinke
    AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    // ✅ Sad smeš da promeniš lozinku
    await user.updatePassword(newPassword);

    await _db.collection('users').doc(userId).update({
        'isPasswordChangeNeeded': false
      });
      
    print("Password successfully updated.");
  } on FirebaseAuthException catch (e) {
    if (e.code == 'wrong-password') {
      print("Current password is incorrect.");
    } else {
      print("FirebaseAuthException during password change: $e");
    }
    rethrow;
  } catch (e) {
    print("Exception during password change: $e");
    rethrow;
  }
}

Future<void> setPremiumFlag(String userId) async {
  try {
    
    await _db.collection('users').doc(userId).update({
        'isPremium': true
      });
      
 
  } catch (e) {
    print("Exception during password change: $e");
    rethrow;
  }
}
Future<void> removePremiumFlag(String userId) async {
  try {
    
    await _db.collection('users').doc(userId).update({
        'isPremium': false
      });
      
 
  } catch (e) {
    print("Exception during password change: $e");
    rethrow;
  }
}

Future<void> activateUser(String userId) async {
  try {
    
    await _db.collection('users').doc(userId).update({
        'isActive': true
      });
      
 
  } catch (e) {
    print("Exception during password change: $e");
    rethrow;
  }
}
Future<void> deactivateUser(String userId) async {
  try {
    
    await _db.collection('users').doc(userId).update({
        'isActive': false
      });
      
 
  } catch (e) {
    print("Exception during password change: $e");
    rethrow;
  }
}
  Future<void> updateUserProfileImage(String userId, File file) async
  {
    try {
      await _db.collection('users').doc(userId).update({
        'imageUrl': null,
        'thumbUrl': null,
        'imagePath': null,
        'thumbPath': null,
        'localImagePath': file.path,
      });

      Map<String, String>? uploadImageResult = await uploadImage(file, 'slika2');
      
      String? imagePath= uploadImageResult?["fullPath"];

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
    } catch (e) {
      
    }
  }
}