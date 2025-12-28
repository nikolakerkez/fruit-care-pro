import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageDetailsScreen extends StatefulWidget {
  final String chatId;
  final String messageId;

  const MessageDetailsScreen({
    super.key,
    required this.chatId,
    required this.messageId,
  });

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  final UserService _userService = UserService();
  
  Map<String, dynamic>? _messageData;
  List<Map<String, dynamic>> _readByUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessageInfo();
  }

  Future<void> _loadMessageInfo() async {
    try {
      // 1. Dohvati poruku
      final messageDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(widget.messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data()!;
      final readBy = messageData['readBy'] as Map<String, dynamic>? ?? {};

      // 2. Dohvati info o korisnicima koji su pročitali
      final List<Map<String, dynamic>> readByUsers = [];

      for (var entry in readBy.entries) {
        final userId = entry.key;
        final readTimestamp = entry.value as Timestamp;

        // Dohvati user info
        final user = await _userService.getUserById(userId);

        readByUsers.add({
          'user': user,
          'readAt': readTimestamp,
        });
      }

      // Sortiraj po vremenu čitanja (najnovije prvo)
      readByUsers.sort((a, b) {
        final aTime = (a['readAt'] as Timestamp).toDate();
        final bTime = (b['readAt'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _messageData = messageData;
          _readByUsers = readByUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading message info: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Informacije o poruci', style: TextStyle(color: Colors.white, fontSize: 22)),
          backgroundColor: Colors.green[800],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_messageData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Informacije o poruci', style: TextStyle(color: Colors.white, fontSize: 22)),
          backgroundColor: Colors.green[800],
        ),
        body: const Center(child: Text('Poruka nije pronađena')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacije o poruci', style: TextStyle(color: Colors.white, fontSize: 22)),
        backgroundColor: Colors.green[800],
      ),
      body: Column(
        children: [
          // Message preview
          _buildMessagePreview(),

          const Divider(height: 1),

          // Read by section
          Expanded(
            child: _readByUsers.isEmpty
                ? const Center(
                    child: Text(
                      'Niko još nije pročitao ovu poruku',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _readByUsers.length,
                    itemBuilder: (context, index) {
                      return _buildReadByTile(_readByUsers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePreview() {
    final message = _messageData!['message'] as String? ?? '';
    final imageUrl = _messageData!['thumbUrl'] as String?;
    final timestamp = _messageData!['timestamp'] as Timestamp?;

    final time = timestamp?.toDate();
    final formattedTime = time != null
        ? '${time.day}.${time.month}.${time.year}. ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Poruka:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          
          // Image preview
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Text message
          if (message.isNotEmpty)
            Text(
              message,
              style: const TextStyle(fontSize: 15),
            ),

          const SizedBox(height: 8),

          // Timestamp
          Text(
            formattedTime,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadByTile(Map<String, dynamic> data) {
    final user = data['user'] as AppUser?;
    final readAt = data['readAt'] as Timestamp;

    final time = readAt.toDate();
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return ListTile(
      leading: _buildAvatar(user?.thumbUrl),
      title: Text(
        user?.name ?? 'Nepoznat korisnik',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('Pročitano: $formattedTime'),
      trailing: Icon(
        Icons.done_all,
        color: Colors.blue[300],
        size: 20,
      ),
    );
  }

  Widget _buildAvatar(String? thumbUrl) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green[300] ?? Colors.green,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: thumbUrl == null
            ? const Icon(Icons.person, size: 25)
            : CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Icon(Icons.person),
                errorWidget: (_, __, ___) => const Icon(Icons.person),
              ),
      ),
    );
  }
}
