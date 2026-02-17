import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Admin reset user password
  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Niste prijavljeni');
    }

    print('🔍 FirebaseAuth.currentUser: ${currentUser.uid}');
    print('🔍 Email: ${currentUser.email}');
    try {
      final result = await _functions.httpsCallable('adminResetPassword').call({
        'userId': userId,
        'newPassword': newPassword,
      });

      print('Password reset success: ${result.data['message']}');
    } on FirebaseFunctionsException catch (e) {
      print('Firebase Functions error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Greška pri resetovanju lozinke');
    } catch (e) {
      print('Error resetting password: $e');
      throw Exception('Greška pri resetovanju lozinke');
    }
  }
}
