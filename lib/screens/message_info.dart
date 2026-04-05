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
  List<Map<String, dynamic>> _notReadUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessageInfo();
  }

  Future<void> _loadMessageInfo() async {
    try {
      // 1. Dohvati poruku i chat dokument paralelno
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(widget.messageId)
            .get(),
        FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .get(),
      ]);

      final messageDoc = results[0] as DocumentSnapshot;
      final chatDoc = results[1] as DocumentSnapshot;

      if (!messageDoc.exists) throw Exception('Message not found');

      final messageData = messageDoc.data() as Map<String, dynamic>;
      final readBy = messageData['readBy'] as Map<String, dynamic>? ?? {};
      final senderId = messageData['senderId'] as String? ?? '';

      // 2. Dohvati sve memberIds iz chata (isključi pošiljaoca)
      final chatData = chatDoc.data() as Map<String, dynamic>? ?? {};
      final memberIds = List<String>.from(chatData['memberIds'] ?? [])
        ..remove(senderId);

      // 3. Dohvati info o svim korisnicima paralelno
      final userFutures = memberIds.map((id) => _userService.getUserById(id));
      final users = await Future.wait(userFutures);

      final List<Map<String, dynamic>> readByUsers = [];
      final List<Map<String, dynamic>> notReadUsers = [];

      for (int i = 0; i < memberIds.length; i++) {
        final userId = memberIds[i];
        final user = users[i];

        if (readBy.containsKey(userId)) {
          final readTimestamp = readBy[userId] as Timestamp;
          readByUsers.add({'user': user, 'readAt': readTimestamp});
        } else {
          notReadUsers.add({'user': user});
        }
      }

      // Sortiraj pročitane po vremenu (najnovije prvo)
      readByUsers.sort((a, b) {
        final aTime = (a['readAt'] as Timestamp).toDate();
        final bTime = (b['readAt'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      // Sortiraj nepročitane po imenu
      notReadUsers.sort((a, b) {
        final aName = (a['user'] as AppUser?)?.name ?? '';
        final bName = (b['user'] as AppUser?)?.name ?? '';
        return aName.compareTo(bName);
      });

      if (mounted) {
        setState(() {
          _messageData = messageData;
          _readByUsers = readByUsers;
          _notReadUsers = notReadUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading message info: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Informacije o poruci')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_messageData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Informacije o poruci')),
        body: const Center(child: Text('Poruka nije pronađena')),
      );
    }

    final totalRecipients = _readByUsers.length + _notReadUsers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacije o poruci'),
      ),
      body: Column(
        children: [
          _buildMessagePreview(),
          const Divider(height: 1),

          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[50],
            child: Row(
              children: [
                _buildSummaryChip(
                  icon: Icons.done_all,
                  color: const Color(0xFF1A7A30),
                  label: 'Pročitalo ${_readByUsers.length}/$totalRecipients',
                ),
                const SizedBox(width: 12),
                if (_notReadUsers.isNotEmpty)
                  _buildSummaryChip(
                    icon: Icons.schedule,
                    color: Colors.grey[600]!,
                    label: 'Čeka ${_notReadUsers.length}',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              children: [
                if (_readByUsers.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.done_all,
                    label: 'Pročitali (${_readByUsers.length})',
                    color: const Color(0xFF1A7A30),
                  ),
                  ..._readByUsers.map((data) => _buildReadTile(data)),
                ],
                if (_notReadUsers.isNotEmpty) ...[
                  if (_readByUsers.isNotEmpty) const Divider(height: 1),
                  _buildSectionHeader(
                    icon: Icons.schedule,
                    label: 'Nisu pročitali (${_notReadUsers.length})',
                    color: Colors.grey[600]!,
                  ),
                  ..._notReadUsers.map((data) => _buildNotReadTile(data)),
                ],
                if (_readByUsers.isEmpty && _notReadUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Nema primalaca',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadTile(Map<String, dynamic> data) {
    final user = data['user'] as AppUser?;
    final readAt = data['readAt'] as Timestamp;
    final time = readAt.toDate();
    final formattedTime =
        '${time.day}.${time.month}.${time.year}. ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return ListTile(
      leading: _buildAvatar(user?.thumbUrl),
      title: Text(
        user?.name ?? 'Nepoznat korisnik',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Pročitano: $formattedTime',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.done_all, color: Color(0xFF1A7A30), size: 20),
    );
  }

  Widget _buildNotReadTile(Map<String, dynamic> data) {
    final user = data['user'] as AppUser?;

    return ListTile(
      leading: _buildAvatar(user?.thumbUrl, dimmed: true),
      title: Text(
        user?.name ?? 'Nepoznat korisnik',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
      subtitle: Text(
        'Nije pročitano',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Icon(Icons.done, color: Colors.grey[400], size: 20),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

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

          if (message.isNotEmpty)
            Text(message, style: const TextStyle(fontSize: 15)),

          const SizedBox(height: 8),

          Text(
            formattedTime,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? thumbUrl, {bool dimmed = false}) {
    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: dimmed ? Colors.grey : (Colors.green[300] ?? Colors.green),
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
      ),
    );
  }
}
