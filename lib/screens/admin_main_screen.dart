import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruit_care_pro/exceptions/get_all_users_exception.dart';

import 'package:fruit_care_pro/models/chat_item.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';

import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/private_chat_screen.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:provider/provider.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  // Services
  late final UserService _userService;
  late final ChatService _chatService;
  // State
  late final AppUser _adminUser;
  Map<String, AppUser> _usersMap = {};
  bool _isLoadingUsers = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// Initialize screen with user data
  Future<void> _initializeScreen() async {
    try {
      _userService = context.read<UserService>();
      _chatService = context.read<ChatService>();

      // Get admin user from CurrentUserService
      final currentUser = CurrentUserService.instance.currentUser;

      if (currentUser == null) {
        // Should not happen, but handle defensively
        if (mounted) {
          _navigateToLogin();
        }
        return;
      }

      _adminUser = currentUser;

      // Load all users for chat display
      await _loadUsers();
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to initialize AdminMainScreen',
        screen: 'AdminMainScreen',
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Greška pri učitavanju podataka';
          _isLoadingUsers = false;
        });
      }
    }
  }

Future<void> _loadUsers() async {
  try {
    setState(() => _isLoadingUsers = true);

    final allUsers = await _userService.getAllUsers();

    if (mounted) {
      setState(() {
        _usersMap = {for (var user in allUsers) user.id: user};
        _isLoadingUsers = false;
        _errorMessage = null;
      });
    }

  } on GetAllUsersException catch (e) {
    // Handle known service errors
    if (!mounted) return;
    
    setState(() {
      _isLoadingUsers = false;
      _errorMessage = e.message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red,
      ),
    );

  } catch (e, stackTrace) {
    // Handle unexpected errors
    await ErrorLogger.logError(
      e,
      stackTrace,
      reason: 'Failed to load users in UI',
      screen: 'AdminMainScreen',
    );

    if (!mounted) return;

    setState(() {
      _isLoadingUsers = false;
      _errorMessage = 'Greška pri učitavanju korisnika';
    });
  }
}

  /// Navigates to login screen (should not happen in normal flow)
  void _navigateToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  /// Handles bottom navigation bar item tap
  void _onItemTapped(int index) {
    // Don't navigate if already on current tab
    if (index == 0) return;

    final routes = <Widget>[
      const AdminMainScreen(), // Index 0 - current screen
      const UserListScreen(), // Index 1
      const FruitListPage(), // Index 2
      const AdvertisementCategoriesScreen(), // Index 3
      UserDetailsScreen(userId: _adminUser.id), // Index 4
    ];

    if (index < routes.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => routes[index]),
      );
    }
  }

  /// Handles chat item tap - navigates to appropriate chat screen
  void _handleChatTap(ChatItem chat) {
    if (chat.isGroup) {
      // Navigate to group chat
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
      // Navigate to private chat
      final otherUserId = chat.getOtherUser(_adminUser.id);

      if (otherUserId == null || otherUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ne mogu da otvorim chat - korisnik nije pronađen'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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

  /// Builds app bar with title
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
              automaticallyImplyLeading: false, // Remove back button
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

  /// Builds main body with chat list
  Widget _buildBody() {
    // Show error if initialization failed
    if (_errorMessage != null && !_isLoadingUsers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<ChatItem>>(
      stream: _chatService.getChatsStreamForUser(_adminUser.id),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          ErrorLogger.logError(
            snapshot.error!,
            StackTrace.current,
            reason: 'Chat stream error',
            screen: 'AdminMainScreen',
          );

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Greška pri učitavanju poruka'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}), // Rebuild to retry
                  child: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nema poruka',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Success state - display chat list
        final chats = snapshot.data!;

        return RefreshIndicator(
          onRefresh: _loadUsers,
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              color: Colors.grey,
              thickness: 1,
              height: 12,
            ),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListTile(
                chat: chat,
                adminId: _adminUser.id,
                usersMap: _usersMap,
                onTap: () => _handleChatTap(chat),
              );
            },
          ),
        );
      },
    );
  }

  /// Builds bottom navigation bar
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
            icon: Icon(Icons.person),
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

/// Individual chat list item widget
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
      trailing: hasUnread
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  /// Gets chat title (group name or user name)
  String _getChatTitle(String otherUserId) {
    if (chat.isGroup) {
      return chat.name ?? 'Nepoznat chat';
    }
    return usersMap[otherUserId]?.name ?? 'Nepoznat korisnik';
  }

  /// Gets thumbnail URL for private chats
  String? _getThumbUrl(String otherUserId) {
    if (chat.isGroup) return null;
    return usersMap[otherUserId]?.thumbUrl;
  }

  /// Builds avatar (profile picture or group icon)
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
              ? const Icon(Icons.groups, size: 32)
              : thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const CircularProgressIndicator(),
                      errorWidget: (_, __, ___) => const Icon(Icons.person),
                    )
                  : const Icon(Icons.person, size: 32),
        ),
      ),
    );
  }

  /// Builds subtitle with last message preview and timestamp
  Widget _buildSubtitle(LastMessage? lastMessage, bool hasUnread) {
    if (lastMessage == null) {
      return const Text(
        'Nema poruka',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastMessage.getTruncatedText(maxLength: 30),
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            color: hasUnread ? Colors.black : Colors.grey[700],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          formatChatTime(lastMessage.timestamp.toDate()),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
