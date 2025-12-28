import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/models/chat_item_member.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatListTile extends StatelessWidget {
  final ChatItem chat;
  final ChatItemMember member;
  final AppUser? otherUser;
  final VoidCallback onTap;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.member,
    required this.otherUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String title = chat.isGroup ? chat.name ?? "Grupni chat" : otherUser?.name ?? "Nepoznat korisnik";

    String truncatedMessage = member.message.length > 30
        ? '${member.message.substring(0, 30)}...'
        : member.message;

    bool isRead = member.read || member.message == "-";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[800] ?? Colors.orange, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.green[800],
                      fontSize: 18,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    truncatedMessage,
                    style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  Text(
                    timeago.format(member.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (chat.isGroup) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.brown[300] ?? Colors.brown, width: 2),
        ),
        child: const Icon(Icons.groups, size: 30),
      );
    } else {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.brown[300] ?? Colors.brown, width: 2),
        ),
        child: ClipOval(
          child: otherUser?.thumbUrl != null
              ? CachedNetworkImage(
                  imageUrl: otherUser!.thumbUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Icon(Icons.person),
                  errorWidget: (context, url, error) => const Icon(Icons.person),
                )
              : const Icon(Icons.person),
        ),
      );
    }
  }
}
