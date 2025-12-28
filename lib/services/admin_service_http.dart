import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class AdminServiceHttp {
  static const String _baseUrl = 'https://us-central1-fruit-care-pro.cloudfunctions.net';

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