import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';

import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/private_chat_screen.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  // Services
  late final ChatService _chatService;

  // State
  late final AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    
    // Get current user
    final currentUser = CurrentUserService.instance.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return;
    }
    _currentUser = currentUser;

    // Get service from Provider
    _chatService = context.read<ChatService>();
  }

  void _onItemTapped(int index) {
    // Don't navigate if already on current tab
    if (index == 0) return;

    final routes = [
      () => const UserMainScreen(),
      () => const AdvertisementCategoriesScreen(),
      () => UserDetailsScreen(userId: _currentUser.id),
    ];

    if (index < routes.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => routes[index]()),
      );
    }
  }

  void _handleChatTap(ChatItem chat) {
    if (chat.isGroup) {
      Navigator.pushNamed(
        context,
        '/group-chat',
        arguments: {
          'chatId': chat.id,
          'fruitTypeId': chat.id,
          'fruitTypeName': chat.name,
        },
      );
    } else {
      final otherUserId = chat.getOtherUser(_currentUser.id) ?? '';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrivateChatScreen.asUser(
            chatId: chat.id,
            userId: otherUserId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 3),
      child: Container(
        color: Colors.green[800],
        child: Column(
          children: [
            AppBar(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              title: const Text(
                'Poruke',
                style: TextStyle(color: Colors.white),
              ),
            ),
            Container(
              height: 3,
              color: Colors.brown[500],
              child:    FloatingActionButton(
  onPressed: () async {
    final token = await FirebaseMessaging.instance.getToken();
    final permission = await FirebaseMessaging.instance.getNotificationSettings();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Push Notification Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permission: ${permission.authorizationStatus}'),
            SizedBox(height: 10),
            Text('Token:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(token ?? 'NO TOKEN'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  },
  child: Icon(Icons.notifications),
)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<ChatItem>>(
      stream: _chatService.getChatsStreamForUser(_currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nema poruka'));
        }

        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, __) => const Divider(
            color: Colors.grey,
            thickness: 1,
            height: 12,
          ),
          itemBuilder: (context, index) {
            final chat = snapshot.data![index];
            return _ChatListTile(
              chat: chat,
              userId: _currentUser.id,
              onTap: () => _handleChatTap(chat),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.brown[500] ?? Colors.brown,
            width: 2,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.brown[500],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Poruke',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Istraži',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2_sharp),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHAT LIST TILE WIDGET
// ============================================================================

class _ChatListTile extends StatelessWidget {
  final ChatItem chat;
  final String userId;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.chat,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chatTitle = _getChatTitle();
    final thumbUrl = _getThumbUrl();
    final lastMessage = chat.lastMessage;
    final hasUnread = chat.hasUnreadLastMessage(userId);

    return ListTile(
      leading: _buildAvatar(thumbUrl),
      title: Text(
        chatTitle,
        style: TextStyle(
          fontWeight:
              lastMessage == null || lastMessage.text == '' || !hasUnread
                  ? FontWeight.normal
                  : FontWeight.bold,
          fontSize: 16.5,
        ),
      ),
      subtitle: _buildSubtitle(lastMessage, hasUnread),
      onTap: onTap,
    );
  }

  String _getChatTitle() {
    if (chat.isGroup || chat.memberIds.isEmpty) {
      return chat.name ?? 'Nepoznat chat';
    }
    return "Admin";
  }

  String? _getThumbUrl() {
    return null;
  }

  Widget _buildAvatar(String? thumbUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.brown[300] ?? Colors.brown,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: AspectRatio(
          aspectRatio: 1,
          child: _buildAvatarContent(thumbUrl),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String? thumbUrl) {
    if (chat.isGroup) {
      return const Icon(Icons.groups);
    }

    if (thumbUrl == null) {
      return const Icon(Icons.person);
    }

    return CachedNetworkImage(
      imageUrl: thumbUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Icon(Icons.person),
      errorWidget: (_, __, ___) => const Icon(Icons.person),
    );
  }

  Widget _buildSubtitle(LastMessage? lastMessage, bool hasUnread) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastMessage != null
              ? lastMessage.getTruncatedText(maxLength: 30)
              : '-',
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          lastMessage != null
              ? formatChatTime(lastMessage.timestamp.toDate())
              : '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}