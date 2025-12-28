import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatItem {
  final String id;
  final String? name;
  final List<String> memberIds;
  final bool isGroup;
  final LastMessage? lastMessage;

  ChatItem({
    required this.id,
    required this.memberIds,
    required this.isGroup,
    this.name,
    this.lastMessage,
  });

factory ChatItem.fromFirestore(DocumentSnapshot doc) {
  try {
    final data = doc.data() as Map<String, dynamic>;
    
    debugPrint('Parsing chat ${doc.id}');

    // Proveri tip lastMessage podatka
    final lastMessageData = data['lastMessage'];
    debugPrint('  lastMessage type: ${lastMessageData.runtimeType}');
    debugPrint('  lastMessage value: $lastMessageData');

    LastMessage? lastMessage;
    
    // Proveri da li je lastMessage mapa
    if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
      lastMessage = LastMessage.fromMap(lastMessageData);
    } else if (lastMessageData != null) {
      debugPrint('⚠️ Warning: lastMessage is not a Map, it is ${lastMessageData.runtimeType}');
      // lastMessage ostaje null
    }

    return ChatItem(
      id: doc.id,
      name: data['name'],
      memberIds: List<String>.from(data['memberIds'] ?? []),
      isGroup: data['type'] == "group" || data['isGroup'] == true,
      lastMessage: lastMessage,
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Error parsing ChatItem: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

  String? getOtherUser(String myUserId) {
    return memberIds.firstWhere(
      (m) => m != myUserId,
      orElse: () => "",
    );
  }
}

class LastMessage {
  final String text;
  final Timestamp timestamp;
  final String senderId;
  final Map<String, Timestamp> readBy;

  LastMessage({
    required this.text,
    required this.timestamp,
    required this.senderId,
    required this.readBy,
  });

  factory LastMessage.fromMap(Map<String, dynamic> map) {
    final readByMap = <String, Timestamp>{};
    final readByData = map['readBy'] as Map<String, dynamic>?;
    
    if (readByData != null) {
      readByData.forEach((key, value) {
        if (value is Timestamp) {
          readByMap[key] = value;
        }
      });
    }

    return LastMessage(
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      senderId: map['senderId'] as String? ?? '',
      readBy: readByMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timestamp': timestamp,
      'senderId': senderId,
      'readBy': readBy,
    };
  }
}

// Extension metode za lakše korišćenje
extension LastMessageExtensions on LastMessage {
  /// Da li je korisnik pročitao poruku
  bool isReadBy(String userId) {
    return readBy.containsKey(userId);
  }

  /// Kada je korisnik pročitao poruku
  DateTime? getReadTimeFor(String userId) {
    return readBy[userId]?.toDate();
  }

  /// Formatirano vreme
  String getFormattedTime() {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Juče';
    } else if (difference.inDays < 7) {
      final days = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      return days[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }

  /// Skraćeni tekst
  String getTruncatedText({int maxLength = 30}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Da li su svi pročitali (osim pošiljaoca)
  bool areAllRead(List<String> memberIds) {
    final recipients = memberIds.where((id) => id != senderId).toList();
    if (recipients.isEmpty) return true;
    return recipients.every((userId) => isReadBy(userId));
  }

  /// Broj pročitanih (bez pošiljaoca)
  int getReadCount(List<String> memberIds) {
    return memberIds
        .where((userId) => userId != senderId && isReadBy(userId))
        .length;
  }
}

extension ChatItemExtensions on ChatItem {
  /// Da li trenutni korisnik ima nepročitanu poslednju poruku
  bool hasUnreadLastMessage(String myUserId) {
    if (lastMessage == null) return false;
    // Ako sam ja poslao, uvek je pročitano za mene
    if (lastMessage!.senderId == myUserId) return false;
    return !lastMessage!.isReadBy(myUserId);
  }

  /// Broj korisnika koji su pročitali (bez pošiljaoca)
  int getLastMessageReadCount() {
    if (lastMessage == null) return 0;
    return lastMessage!.getReadCount(memberIds);
  }

  /// Ukupan broj korisnika koji treba da pročitaju (bez pošiljaoca)
  int getTotalRecipients() {
    if (lastMessage == null) return 0;
    return memberIds.where((id) => id != lastMessage!.senderId).length;
  }
}