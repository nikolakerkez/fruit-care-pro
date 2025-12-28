import 'package:cloud_firestore/cloud_firestore.dart';

class ChatItemMember {
  final String message;
  final DateTime timestamp;
  final bool read;

  ChatItemMember({
    required this.message,
    required this.timestamp,
    required this.read,
  });

  factory ChatItemMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final msg = data?['lastMessage'] ?? {};

    return ChatItemMember(
      message: msg['message'] ?? '',
      timestamp: (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: msg['read'] ?? false,
    );
  }
}
