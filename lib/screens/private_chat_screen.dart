import 'dart:io';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';
import 'package:fruit_care_pro/widgets/chat_bubble.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'dart:async';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:image_picker/image_picker.dart';

enum ChatUserRole { admin, user }

class PrivateChatScreen extends StatefulWidget {
  final String? chatId;
  final String? userId;
  final ChatUserRole role; // 🔥 Novi parametar

  const PrivateChatScreen({
    super.key,
    this.chatId,
    this.userId,
    required this.role,
  });

  // 🔥 Factory konstruktori za lakše pozivanje
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
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StreamController<List<DocumentSnapshot>> _chatStreamController =
      StreamController<List<DocumentSnapshot>>.broadcast();

  // State variables
  String _currentUserId = '';  // 🔥 ID trenutnog korisnika (admin ili user)
  String _otherUserId = '';    // 🔥 ID osobe sa kojom pričamo
  String _chatId = '';
  AppUser? _otherUser;         // 🔥 Osoba sa kojom pričamo
  bool _isLoading = true;
  bool _hasMoreData = true;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  final List<StreamSubscription> _subscriptions = [];

  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => widget.role == ChatUserRole.admin;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupScrollListener();
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _chatStreamController.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initialize() async {
    await _extractRouteParameters();
    await _loadCurrentUserId();
    await _loadOtherUser();
    await _markMessagesAsRead();
    _finalizeInitialization();
  }

  Future<void> _extractRouteParameters() async {
    if (widget.userId != null) {
      _otherUserId = widget.userId!;
    }
    if (widget.chatId != null) {
      _chatId = widget.chatId!;
    }
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = CurrentUserService.instance.currentUser!.id;
  }

  Future<void> _loadOtherUser() async {
    if (_otherUserId.isEmpty) return;

    final user = await _userService.getUserById(_otherUserId);
    if (mounted) {
      setState(() => _otherUser = user);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_chatId.isNotEmpty && _currentUserId.isNotEmpty) {
      await _chatService.markMessagesAsRead(_chatId, _currentUserId);
    }
  }

  void _finalizeInitialization() {
    if (_currentUserId.isNotEmpty && _otherUserId.isNotEmpty && _chatId.isNotEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_isAtScrollThreshold && !_scrollController.position.outOfRange) {
        _loadMoreMessages();
      }
    });
  }

  bool get _isAtScrollThreshold {
    return _scrollController.offset >= _scrollController.position.maxScrollExtent;
  }

  // ==================== CHAT LOADING ====================

  Stream<List<DocumentSnapshot>> _listenToChatsRealTime() {
    _loadMoreMessages();
    return _chatStreamController.stream;
  }

  void _loadMoreMessages() {
    if (!_hasMoreData || _chatId.isEmpty) return;

    final query = _buildMessagesQuery();
    final currentRequestIndex = _allPagedResults.length;

    final subscription = query.snapshots().listen(
      (snapshot) => _handleMessagesSnapshot(snapshot, currentRequestIndex),
      onError: (error) => debugPrint('❌ Error loading messages: $error'),
    );

    _subscriptions.add(subscription);
  }

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

  void _handleMessagesSnapshot(QuerySnapshot snapshot, int currentRequestIndex) {
    if (!mounted) return;

    if (snapshot.docs.isEmpty) {
      if (!_chatStreamController.isClosed) {
        _chatStreamController.add([]);
      }
      setState(() => _hasMoreData = false);
      return;
    }

    _updatePagedResults(snapshot.docs, currentRequestIndex);
    _emitAllMessages();
    _updatePaginationState(snapshot.docs, currentRequestIndex);
  }

  void _emitAllMessages() {
    if (_chatStreamController.isClosed) return;
    final allMessages = _allPagedResults.expand((page) => page).toList();
    _chatStreamController.add(allMessages);
  }

  void _updatePagedResults(List<DocumentSnapshot> docs, int currentRequestIndex) {
    if (currentRequestIndex < _allPagedResults.length) {
      _allPagedResults[currentRequestIndex] = docs;
    } else {
      _allPagedResults.add(docs);
    }
  }

  void _updatePaginationState(List<DocumentSnapshot> docs, int currentRequestIndex) {
    if (currentRequestIndex == _allPagedResults.length - 1) {
      _lastDocument = docs.last;
    }
    _hasMoreData = docs.length == 20;
  }

  // ==================== MESSAGE SENDING ====================

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await _sendMessage(messageText: text);
  }

  Future<void> _sendImageMessage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _chatService.sendMessage(
        _chatId,
        _currentUserId,
        _otherUserId,
        '',
        imageFile,
      );
    }
  }

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

  void _navigateToUserDetails(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsScreen(userId: userId),
      ),
    );
  }

  void _navigateToImageViewer(String? imageUrl, String? localPath, String? messageId) {
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
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_chatId.isEmpty) {
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

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Fruit Care Pro')),
      body: const Center(child: Text('Chat ID nije dostupan.')),
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
              title: _buildAppBarTitle(),
            ),
            Container(height: 3, color: Colors.brown[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    // 🔥 Admin vidi ime korisnika, User vidi "Admin"
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
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? thumbUrl) {
    return Container(
      width: 50,
      height: 50,
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

  Widget _buildMessagesList() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _listenToChatsRealTime(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
                  otherUserId: _otherUserId, // 🔥 Prosledi otherUserId
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildMessageInput() {
    // 🔥 Samo user treba premium check
    final isPremium = _isAdmin ? true : (_currentUser?.isPremium ?? false);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: isPremium ? 1.0 : 0.6,
          child: AbsorbPointer(
            absorbing: !isPremium,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: generateTextField(
                      labelText: isPremium
                          ? 'Unesite poruku'
                          : 'Niste premium korisnik',
                      controller: _messageController,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    color: isPremium ? Colors.brown[500] : Colors.grey,
                    onPressed: isPremium ? _sendImageMessage : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: isPremium ? Colors.brown[500] : Colors.grey,
                    onPressed: isPremium ? _sendTextMessage : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}