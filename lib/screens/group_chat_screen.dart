import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/screens/message_info.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';

class GroupChatScreen extends StatefulWidget {
  final String? chatId;
  final String? fruitTypeId;
  final String? fruitTypeName;

  const GroupChatScreen({
    super.key,
    this.chatId,
    this.fruitTypeId,
    this.fruitTypeName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  // Services
  late final UserService _userService;
  late final ChatService _chatService;
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StreamController<List<DocumentSnapshot>> _chatStreamController =
      StreamController<List<DocumentSnapshot>>.broadcast();

  // State variables
  late final String _myId;
  String _adminId = '';
  String _chatId = '';
  String _fruitTypeId = '';
  String _fruitTypeName = '';
  bool _isLoading = true;
  bool _hasMoreData = true;
  String? _errorMessage;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  final List<StreamSubscription> _subscriptions = [];
  Timestamp? _userLastMessageTimestamp;

  // User state
  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => _currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
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
      _myId = currentUser.id;

      // Get services from Provider
      _userService = context.read<UserService>();
      _chatService = context.read<ChatService>();

      // Extract route parameters
      await _extractRouteParameters();

      // Load admin ID
      await _loadAdminId();

      // Mark messages as read
      await _markMessagesAsRead();

      // Setup scroll listener for pagination
      _setupScrollListener();

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
        reason: 'Failed to initialize GroupChatScreen',
        screen: 'GroupChatScreen',
        additionalData: {
          'chat_id': _chatId,
          'fruit_type_id': _fruitTypeId,
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
    _fruitTypeId = widget.fruitTypeId ?? '';
    _fruitTypeName = widget.fruitTypeName ?? '';

    if (_chatId.isEmpty) {
      throw Exception('Chat ID is required');
    }
  }

  /// Load admin ID from user service
  Future<void> _loadAdminId() async {
    final adminId = await _userService.getAdminId();
    
    if (adminId == null || adminId.isEmpty) {
      throw Exception('Admin ID not found');
    }

    _adminId = adminId;
  }

  /// Mark all messages as read for current user
  Future<void> _markMessagesAsRead() async {
    if (_chatId.isEmpty || _myId.isEmpty) return;

    try {
      await _chatService.markMessagesAsRead(_chatId, _myId);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to mark messages as read',
        screen: 'GroupChatScreen',
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
    _loadMoreMessages();
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
          screen: 'GroupChatScreen',
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

    // Track admin's last message timestamp
    _updateAdminLastMessageTimestamp(snapshot.docs);

    // Update paged results
    _updatePagedResults(snapshot.docs, currentRequestIndex);

    // Emit all messages
    _emitAllMessages();

    // Update pagination state
    _updatePaginationState(snapshot.docs, currentRequestIndex);
  }

  /// Update admin's last message timestamp for read receipts
  void _updateAdminLastMessageTimestamp(List<DocumentSnapshot> docs) {
    try {
      final adminMessages = docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['senderId'] == _adminId;
          })
          .toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          return (bData['timestamp'] as Timestamp).compareTo(
            aData['timestamp'] as Timestamp,
          );
        });

      if (adminMessages.isNotEmpty) {
        final latestData = adminMessages.first.data() as Map<String, dynamic>;
        final latestTimestamp = latestData['timestamp'] as Timestamp;
        
        if (_userLastMessageTimestamp == null ||
            _userLastMessageTimestamp!.compareTo(latestTimestamp) < 0) {
          _userLastMessageTimestamp = latestTimestamp;
        }
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to update admin last message timestamp',
        screen: 'GroupChatScreen',
      );
    }
  }

  /// Emit all messages to stream
  void _emitAllMessages() {
    if (_chatStreamController.isClosed) return;
    
    final allMessages = _allPagedResults.expand((page) => page).toList();
    _chatStreamController.add(allMessages);
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
    if (!_isAdmin) {
      _showAdminOnlyMessage();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await _sendMessage(messageText: text);
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send text message',
        screen: 'GroupChatScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Greška pri slanju poruke'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send image message
  Future<void> _sendImageMessage() async {
    if (!_isAdmin) {
      _showAdminOnlyMessage();
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      
      await _chatService.sendMessage(
        _chatId,
        _adminId,
        _adminId, // For group chat, admin sends to self
        '',
        imageFile,
      );

    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to send image message',
        screen: 'GroupChatScreen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Greška pri slanju slike'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send message to chat
  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    if (_chatId.isEmpty || _adminId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';
    
    await _chatService.sendMessage(
      _chatId,
      _adminId,
      _adminId, // For group chat
      message,
      null,
    );
  }

  /// Show message that only admin can send messages
  void _showAdminOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Samo administrator može slati poruke'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ==================== NAVIGATION ====================

  /// Navigate to message info screen (admin only)
  void _navigateToMessageInfo(String messageId) {
    if (!_isAdmin) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageDetailsScreen(
          chatId: _chatId,
          messageId: messageId,
        ),
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
          if (_isAdmin) _buildMessageInput(),
          if (!_isAdmin) const SizedBox(height: 60),
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
              title: Text(
                _fruitTypeName,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Container(height: 3, color: Colors.brown[500]),
          ],
        ),
      ),
    );
  }

  /// Build messages list
  Widget _buildMessagesList() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _listenToChatsRealTime(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Empty state
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
                GestureDetector(
                  onTap: () => _isAdmin 
                      ? _navigateToMessageInfo(messageDoc.id) 
                      : null,
                  child: _GroupChatBubble(
                    messageData: messageData,
                    isCurrentUser: messageData['senderId'] == _myId,
                    isAdmin: _isAdmin,
                    userLastMessageTimestamp: _userLastMessageTimestamp,
                    onImageTap: () => _navigateToImageViewer(
                      messageData['imageUrl'] ?? messageData['thumbUrl'],
                      messageData['localImagePath'],
                      messageData['messageId'],
                    ),
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

  /// Build message input field (admin only)
  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: generateTextField(
                  labelText: 'Unesite poruku',
                  controller: _messageController,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.image),
                color: Colors.brown[500],
                onPressed: _sendImageMessage,
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.brown[500],
                onPressed: _sendTextMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== GROUP CHAT BUBBLE ====================

class _GroupChatBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isCurrentUser;
  final bool isAdmin;
  final Timestamp? userLastMessageTimestamp;
  final VoidCallback? onImageTap;

  const _GroupChatBubble({
    required this.messageData,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.userLastMessageTimestamp,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = messageData['thumbUrl'] != null ||
        messageData['localImagePath'] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              minWidth: MediaQuery.of(context).size.width * 0.2,
            ),
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.green[800] : Colors.brown[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Image
                    if (hasImage) _buildImage(),

                    // Text message
                    if (_hasText) ...[
                      if (hasImage) const SizedBox(height: 8),
                      Text(
                        messageData['message'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],

                    const SizedBox(height: 4),
                    _buildTimestampWithStatus(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasText => (messageData['message'] as String?)?.isNotEmpty ?? false;

  Widget _buildImage() {
    final isUploading = messageData['isUploading'] ?? false;
    final uploadFailed = messageData['uploadFailed'] ?? false;
    final hasThumb = messageData['thumbUrl'] != null;

    if (isUploading && !hasThumb) {
      return _buildUploadingImage();
    }

    if (uploadFailed && !hasThumb) {
      return _buildFailedImage();
    }

    return GestureDetector(
      onTap: onImageTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(),
      ),
    );
  }

  Widget _buildUploadingImage() {
    final localPath = messageData['localImagePath'] as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            if (localPath != null)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
                child: Image.file(
                  File(localPath),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[300],
              ),
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedImage() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
          const SizedBox(height: 8),
          Text(
            'Upload nije uspeo',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    final thumbUrl = messageData['thumbUrl'] as String?;
    final localPath = messageData['localImagePath'] as String?;

    if (thumbUrl != null) {
      return Image.network(
        thumbUrl,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    if (localPath != null) {
      return Image.file(
        File(localPath),
        height: 200,
        fit: BoxFit.cover,
      );
    }

    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Icon(Icons.image, color: Colors.white, size: 50),
    );
  }

  Widget _buildTimestampWithStatus() {
    final timestamp = messageData['timestamp'] as Timestamp?;
    if (timestamp == null) return const SizedBox.shrink();

    final time = timestamp.toDate();
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedTime,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        // Read status - only if admin sent message after user's last access
        if (isAdmin && _shouldShowReadIcon(timestamp)) ...[
          const SizedBox(width: 4),
          _buildReadStatusIcon(),
        ],
      ],
    );
  }

  bool _shouldShowReadIcon(Timestamp timestamp) {
    if (userLastMessageTimestamp == null) return false;
    return userLastMessageTimestamp!.compareTo(timestamp) < 0;
  }

  Widget _buildReadStatusIcon() {
    final isRead = messageData['isRead'] ?? false;

    return Icon(
      isRead ? Icons.check_circle : Icons.check_circle_outline,
      color: Colors.white,
      size: 16,
    );
  }
}