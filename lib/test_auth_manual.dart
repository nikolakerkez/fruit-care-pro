import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testAuthManual() async {
  print('═══════════════════════════════════════');
  print('🧪 MANUAL AUTH TEST (using dart:io)');
  
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser == null) {
    print('❌ Not logged in');
    return;
  }
  
  print('👤 User: ${currentUser.uid}');
  print('📧 Email: ${currentUser.email}');
  
  try {
    print('🔑 Getting ID token...');
    final idToken = await currentUser.getIdToken(true);
    
    if (idToken == null) {
      print('❌ Token is null!');
      return;
    }
    
    print('✅ Token exists (length: ${idToken.length})');
    print('   First 50: ${idToken.substring(0, 50)}...');
    
    // Manual HTTP request using dart:io
    final url = Uri.parse('https://us-central1-bb-agro-portal.cloudfunctions.net/testAuth');
    
    print('📞 Calling: $url');
    
    final client = HttpClient();
    final request = await client.postUrl(url);
    
    // Set headers
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $idToken');
    
    // Set body
    final body = jsonEncode({
      'data': {
        'test': 'manual',
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
    
    request.write(body);
    
    // Send request
    final response = await request.close();
    
    print('📦 Response status: ${response.statusCode}');
    
    // Read response
    final responseBody = await response.transform(utf8.decoder).join();
    print('📦 Response body: $responseBody');
    
    client.close();
    
    print('═══════════════════════════════════════');
    
  } catch (e) {
    print('❌ Error: $e');
    print('═══════════════════════════════════════');
  }
}