import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fruit_care_pro/models/user_fruit_type.dart';

class AdminCreateUserResult {
  final bool success;
  final bool notUniqueUsername;
  final String? userId;
  final String? error;

  AdminCreateUserResult({
    required this.success,
    this.notUniqueUsername = false,
    this.userId,
    this.error,
  });
}

class AdminServiceHttp {
  static const String _baseUrl = 'https://us-central1-fruit-care-pro.cloudfunctions.net';

  /// Create a new user account (Auth + Firestore) via Cloud Function.
  /// Runs entirely server-side so it does not affect the calling admin's
  /// own Auth session (unlike the old client-side createUserWithEmailAndPassword,
  /// which silently logged the admin in as the newly created user).
  Future<AdminCreateUserResult> createUser({
    required String name,
    required String email,
    required String password,
    required String city,
    required String phone,
    required List<UserFruitType> fruitTypes,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Niste prijavljeni');
    }

    try {
      final idToken = await currentUser.getIdToken(true);

      if (idToken == null) {
        throw Exception('Nije moguće dobiti ID token');
      }

      final url = Uri.parse('$_baseUrl/adminCreateUserHttp');
      final client = HttpClient();
      final request = await client.postUrl(url);

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $idToken');

      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'city': city,
        'phone': phone,
        'fruitTypes': fruitTypes
            .map((ft) => {
                  'fruitTypeId': ft.fruitTypeId,
                  'numberOfTrees': ft.numberOfTrees,
                })
            .toList(),
      });

      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final result = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return AdminCreateUserResult(
          success: result['success'] == true,
          notUniqueUsername: result['notUniqueUsername'] == true,
          userId: result['userId'],
        );
      } else {
        return AdminCreateUserResult(
          success: false,
          error: result['error'] ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return AdminCreateUserResult(success: false, error: e.toString());
    }
  }

  /// Reset user password using direct HTTP call
  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Niste prijavljeni');
    }

    if (newPassword.length < 6) {
      throw Exception('Lozinka mora imati minimum 6 karaktera');
    }

    try {
      print('🔑 Getting ID token...');
      final idToken = await currentUser.getIdToken(true);

      if (idToken == null) {
        throw Exception('Nije moguće dobiti ID token');
      }

      print('📞 Calling adminResetPasswordHttp...');  // ✅ Ispravi print

      // 🔥 KLJUČNA IZMENA: Pozovi NOVU funkciju
      final url = Uri.parse('$_baseUrl/adminResetPasswordHttp');  // ✅ Dodaj Http na kraj!
      final client = HttpClient();
      final request = await client.postUrl(url);

      // Set headers
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $idToken');

      // 🔥 PROMENJEN BODY FORMAT: Običan JSON (NE callable format)
      final body = jsonEncode({
        'userId': userId,           // ✅ Direktno, bez 'data' wrappera
        'newPassword': newPassword,
      });

      request.write(body);

      // Send request
      final response = await request.close();

      // Read response
      final responseBody = await response.transform(utf8.decoder).join();

      print('📦 Response status: ${response.statusCode}');
      print('📦 Response body: $responseBody');

      client.close();

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody);

        // Check for success
        if (result['success'] == true) {
          print('✅ Password reset successful');
          return;
        } else {
          throw Exception(result['error'] ?? 'Greška pri resetovanju lozinke');
        }
      } else {
        final result = jsonDecode(responseBody);
        throw Exception(result['error'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }
}