import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/private_chat_screen.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'users_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/current_user_service.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  Map<String, AppUser> _usersMap = {};
  late final AppUser _adminUser;

  @override
  void initState() {
    super.initState();
    _adminUser = CurrentUserService.instance.currentUser!;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final allUsers = await _userService.getAllUsers();
    if (mounted) {
      setState(() {
        _usersMap = {for (var user in allUsers) user.id: user};
      });
    }
  }

  void _onItemTapped(int index) {
    final routes = [
      () => const AdminMainScreen(),
      () => const UserListScreen(),
      () => const FruitListPage(),
      () => const AdvertisementCategoriesScreen(),
      () => UserDetailsScreen(userId: _adminUser.id),
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
      final otherUserId = chat.getOtherUser(_adminUser.id) ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrivateChatScreen.asAdmin(
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
              backgroundColor: Colors.transparent,
              title: const Text(
                'Poruke',
                style: TextStyle(color: Colors.white),
              ),
            ),
            Container(
              height: 3,
              color: Colors.brown[500],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<ChatItem>>(
      stream: _chatService.getChatsStreamForUser(_adminUser.id),
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
              adminId: _adminUser.id,
              usersMap: _usersMap,
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
            icon: Icon(Icons.people),
            label: 'Korisnici',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forest),
            label: 'Voćne vrste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: 'Reklame',
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

class _ChatListTile extends StatelessWidget {
  final ChatItem chat;
  final String adminId;
  final Map<String, AppUser> usersMap;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.chat,
    required this.adminId,
    required this.usersMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.getOtherUser(adminId) ?? '';
    final chatTitle = _getChatTitle(otherUserId);
    final thumbUrl = _getThumbUrl(otherUserId);
    final lastMessage = chat.lastMessage;
    final hasUnread = chat.hasUnreadLastMessage(adminId);

    return ListTile(
      leading: _buildAvatar(thumbUrl),
      title: Text(
        chatTitle,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
          fontSize: 16.5,
        ),
      ),
      subtitle: _buildSubtitle(lastMessage, hasUnread),
      onTap: onTap,
    );
  }

  String _getChatTitle(String otherUserId) {
    if (chat.isGroup) {
      return chat.name ?? 'Nepoznat chat';
    }
    return usersMap[otherUserId]?.name ?? 'Nepoznat korisnik';
  }

  String? _getThumbUrl(String otherUserId) {
    if (chat.isGroup) return null;
    return usersMap[otherUserId]?.thumbUrl;
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
          child: chat.isGroup
              ? const Icon(Icons.groups)
              : thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Icon(Icons.person),
                      errorWidget: (_, __, ___) => const Icon(Icons.person),
                    )
                  : const Icon(Icons.person),
        ),
      ),
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
