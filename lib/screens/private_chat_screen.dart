import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruit_care_pro/exceptions/chat_exception.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/widgets/chat_bubble.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';

enum ChatUserRole { admin, user }

class PrivateChatScreen extends StatefulWidget {
  final String? chatId;
  final String? userId;
  final ChatUserRole role;

  const PrivateChatScreen({
    super.key,
    this.chatId,
    this.userId,
    required this.role,
  });

  /// Factory constructor for admin user
  factory PrivateChatScreen.asAdmin({
    String? chatId,
    String? userId,
  }) {
    return PrivateChatScreen(
      chatId: chatId,
      userId: userId,
      role: ChatUserRole.admin,
    );
  }

  /// Factory constructor for regular user
  factory PrivateChatScreen.asUser({
    String? chatId,
    String? userId,
  }) {
    return PrivateChatScreen(
      chatId: chatId,
      userId: userId,
      role: ChatUserRole.user,
    );
  }

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  // Services
  late final UserService _userService;
  late final ChatService _chatService;
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StreamController<List<DocumentSnapshot>> _chatStreamController =
      StreamController<List<DocumentSnapshot>>();

  // State variables
  String _currentUserId = '';
  String _otherUserId = '';
  String _chatId = '';
  AppUser? _otherUser;
  bool _isLoading = true;
  bool _hasMoreData = true;
  String? _errorMessage;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  final List<StreamSubscription> _subscriptions = [];

  // User state
  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => widget.role == ChatUserRole.admin;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server ne odgovara. Pokušajte ponovo.';
        });
      }
    });
    // Rebuild when current user's data changes (e.g. isPremium toggled by admin)
    _subscriptions.add(
      CurrentUserService.instance.userUpdates.listen((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Close stream controller
    _chatStreamController.close();

    // Dispose controllers
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  /// Initialize screen with all necessary data
  Future<void> _initializeScreen() async {
    try {
      // Get current user
      final currentUser = CurrentUserService.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
      _currentUserId = currentUser.id;

      // Get services from Provider
      _userService = context.read<UserService>();
      _chatService = context.read<ChatService>();

      // Extract route parameters
      await _extractRouteParameters();

      // Load other user info (with timeout)
      await _loadOtherUser().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Timeout pri učitavanju podataka korisnika'),
      );

      // Mark messages as read — non-critical, run in background
      _markMessagesAsRead();

      // Setup scroll listener for pagination
      _setupScrollListener();

      // Load initial messages
      _loadMoreMessages();

      // Finalize initialization
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to initialize PrivateChatScreen',
        screen: 'PrivateChatScreen',
        additionalData: {
          'chat_id': _chatId,
          'other_user_id': _otherUserId,
          'role': _isAdmin ? 'admin' : 'user',
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Greška pri učitavanju chata';
        });
      }
    }
  }

  /// Extract route parameters from widget
  Future<void> _extractRouteParameters() async {
    _chatId = widget.chatId ?? '';
    _otherUserId = widget.userId ?? '';

    if (_chatId.isEmpty) {
      throw Exception('Chat ID is required');
    }

    if (_otherUserId.isEmpty) {
      throw Exception('Other user ID is required');
    }
  }

  /// Load other user information
  Future<void> _loadOtherUser() async {
    if (_otherUserId.isEmpty) return;

    try {
      final user = await _userService.getUserById(_otherUserId);
      
      if (mounted) {
        setState(() => _otherUser = user);
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to load other user',
        screen: 'PrivateChatScreen',
        additionalData: {'other_user_id': _otherUserId},
      );
      // Non-critical - continue without user info
    }
  }

  /// Mark all messages as read for current user
  Future<void> _markMessagesAsRead() async {
    if (_chatId.isEmpty || _currentUserId.isEmpty) return;

    try {
      await _chatService.markMessagesAsRead(_chatId, _currentUserId);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to mark messages as read',
        screen: 'PrivateChatScreen',
        additionalData: {'chat_id': _chatId},
      );
      // Non-critical error, continue
    }
  }

  /// Setup scroll listener for pagination
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_isAtScrollThreshold && !_scrollController.position.outOfRange) {
        _loadMoreMessages();
      }
    });
  }

  /// Check if scroll is at threshold for loading more messages
  bool get _isAtScrollThreshold {
    return _scrollController.offset >= _scrollController.position.maxScrollExtent;
  }

  // ==================== CHAT LOADING ====================

  /// Stream of chat messages with pagination
  Stream<List<DocumentSnapshot>> _listenToChatsRealTime() {
    return _chatStreamController.stream;
  }

  /// Load more messages (pagination)
  void _loadMoreMessages() {
    if (!_hasMoreData || _chatId.isEmpty) return;

    final query = _buildMessagesQuery();
    final currentRequestIndex = _allPagedResults.length;

    final subscription = query.snapshots().listen(
      (snapshot) => _handleMessagesSnapshot(snapshot, currentRequestIndex),
      onError: (error, stackTrace) {
        ErrorLogger.logError(
          error,
          stackTrace,
          reason: 'Error in messages stream',
          screen: 'PrivateChatScreen',
          additionalData: {'chat_id': _chatId},
        );
      },
    );

    _subscriptions.add(subscription);
  }

  /// Build Firestore query for messages
  Query<Map<String, dynamic>> _buildMessagesQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    return query;
  }

  /// Handle snapshot from messages query
  void _handleMessagesSnapshot(
    QuerySnapshot snapshot,
    int currentRequestIndex,
  ) {
    if (!mounted) return;

    // Empty snapshot - no more messages
    if (snapshot.docs.isEmpty) {
      if (!_chatStreamController.isClosed) {
        _chatStreamController.add([]);
      }
      setState(() => _hasMoreData = false);
      return;
    }

    // Update paged results
    _updatePagedResults(snapshot.docs, currentRequestIndex);

    // Emit all messages
    _emitAllMessages();

    // Update pagination state
    _updatePaginationState(snapshot.docs, currentRequestIndex);
  }

  /// Emit all messages to stream
  void _emitAllMessages() {
    if (_chatStreamController.isClosed) return;

    final allMessages = _allPagedResults.expand((page) => page).toList();
    _chatStreamController.add(allMessages);

    // Mark incoming messages as read while chat is open
    _markMessagesAsRead();
  }

  /// Update paged results with new documents
  void _updatePagedResults(
    List<DocumentSnapshot> docs,
    int currentRequestIndex,
  ) {
    if (currentRequestIndex < _allPagedResults.length) {
      _allPagedResults[currentRequestIndex] = docs;
    } else {
      _allPagedResults.add(docs);
    }
  }

  /// Update pagination state
  void _updatePaginationState(
    List<DocumentSnapshot> docs,
    int currentRequestIndex,
  ) {
    if (currentRequestIndex == _allPagedResults.length - 1) {
      _lastDocument = docs.last;
    }
    _hasMoreData = docs.length == 20;
  }

  // ==================== MESSAGE SENDING ====================

  /// Send text message
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await _sendMessage(messageText: text);
    } on SendMessageException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send text message',
        screen: 'PrivateChatScreen',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri slanju poruke'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Send image message
  Future<void> _sendImageMessage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);

      await _chatService.sendMessage(
        _chatId,
        _currentUserId,
        _otherUserId,
        '',
        imageFile,
      );
    } on SendMessageException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send image message',
        screen: 'PrivateChatScreen',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri slanju slike'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Send message to chat
  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    if (_chatId.isEmpty || _otherUserId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';

    await _chatService.sendMessage(
      _chatId,
      _currentUserId,
      _otherUserId,
      message,
      null,
    );
  }

  // ==================== NAVIGATION ====================

  /// Navigate to user details screen
  void _navigateToUserDetails(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsScreen(userId: userId),
      ),
    );
  }

  /// Navigate to full screen image viewer
  void _navigateToImageViewer(
    String? imageUrl,
    String? localPath,
    String? messageId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          localPath: localPath,
          messageId: messageId,
        ),
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Error state
    if (_errorMessage != null || _chatId.isEmpty) {
      return _buildErrorScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Build error screen
  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Greška')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Chat ID nije dostupan.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: false,
      title: _buildAppBarTitle(),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: ColoredBox(
          color: Color(0xFF2E7D52),
          child: SizedBox(height: 2, width: double.infinity),
        ),
      ),
    );
  }

  /// Build app bar title with avatar and name
  Widget _buildAppBarTitle() {
    // Admin sees user name, regular user sees "Admin"
    final displayName = _isAdmin ? (_otherUser?.name ?? '') : 'Admin';

    return Row(
      children: [
        const SizedBox(width: 30),
        GestureDetector(
          onTap: () => _navigateToUserDetails(_otherUserId),
          child: _buildAvatar(_otherUser?.thumbUrl),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _navigateToUserDetails(_otherUserId),
          child: Text(
            displayName,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Build avatar
  Widget _buildAvatar(String? thumbUrl) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: Border.all(
          color: const Color(0xFF2E7D52),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: AspectRatio(
          aspectRatio: 1,
          child: thumbUrl == null
              ? const Icon(Icons.person)
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

  /// Build messages list
  Widget _buildMessagesList() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _listenToChatsRealTime(),
      builder: (context, snapshot) {
        // Empty state (also covers waiting - don't block UI on stream)
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Započnite razgovor.'));
        }

        final messages = snapshot.data!;

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final messageDoc = messages[index];
            final messageData = messageDoc.data() as Map<String, dynamic>;
            final showDateSeparator = _shouldShowDateSeparator(messages, index);

            return Column(
              children: [
                if (showDateSeparator)
                  DateSeparator(
                    timestamp: messageData['timestamp'] as Timestamp?,
                  ),
                ChatBubble(
                  messageData: messageData,
                  isCurrentUser: messageData['senderId'] == _currentUserId,
                  otherUserId: _otherUserId,
                  onImageTap: () => _navigateToImageViewer(
                    messageData['imageUrl'] ?? messageData['thumbUrl'],
                    messageData['localImagePath'],
                    messageData['messageId'],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Check if should show date separator
  bool _shouldShowDateSeparator(List<DocumentSnapshot> messages, int index) {
    if (index == messages.length - 1) return true;

    final currentMessage = messages[index].data() as Map<String, dynamic>;
    final nextMessage = messages[index + 1].data() as Map<String, dynamic>;

    final currentTimestamp = currentMessage['timestamp'] as Timestamp?;
    final nextTimestamp = nextMessage['timestamp'] as Timestamp?;

    if (currentTimestamp == null || nextTimestamp == null) return false;

    final currentDate = currentTimestamp.toDate();
    final nextDate = nextTimestamp.toDate();

    return !_isSameDay(currentDate, nextDate);
  }

  /// Check if two dates are on same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Build message input field
  Widget _buildMessageInput() {
    // Only regular users need premium check, admin always has access
    final isPremium = _isAdmin ? true : (_currentUser?.isPremium ?? false);

    return SafeArea(
      child: Opacity(
        opacity: isPremium ? 1.0 : 0.6,
        child: AbsorbPointer(
          absorbing: !isPremium,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: generateTextField(
                    labelText: isPremium ? 'Unesite poruku' : 'Niste premium korisnik',
                    controller: _messageController,
                  ),
                ),
                const SizedBox(width: 4),
                _buildInputButton(Icons.image_outlined, isPremium ? _sendImageMessage : () {}),
                _buildInputButton(Icons.send_rounded, isPremium ? _sendTextMessage : () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF388E3C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}