import 'package:cloud_firestore/cloud_firestore.dart'; // Za Firestore


class Message {
  final String text; // Tekst poruke
  final String senderId; // ID pošiljaoca (userId ili adminId)
  final Timestamp timestamp; // Vreme kada je poruka poslata

  // Konstruktor
  Message({
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  // Metoda koja omogućava kreiranje Message objekta iz Firestore dokumenta
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Message(
      text: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
