import 'dart:io';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';
import 'package:fruit_care_pro/screens/message_info.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

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
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StreamController<List<DocumentSnapshot>> _chatStreamController =
      StreamController<List<DocumentSnapshot>>.broadcast();

  // State variables
  late final String _myId; // ID trenutnog korisnika
  String _adminId = '';
  String _chatId = '';
  String _fruitTypeId = '';
  String _fruitTypeName = '';
  bool _isLoading = true;
  bool _hasMoreData = true;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  final List<StreamSubscription> _subscriptions = [];
  Timestamp? _userLastMessageTimestamp;

  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => _currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _myId = CurrentUserService.instance.currentUser!.id;
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
    await _loadAdminId();
    await _markMessagesAsRead();
    _finalizeInitialization();
  }

  Future<void> _extractRouteParameters() async {
    if (widget.fruitTypeId != null) {
      _fruitTypeId = widget.fruitTypeId!;
    }
    if (widget.fruitTypeName != null) {
      _fruitTypeName = widget.fruitTypeName!;
    }
    if (widget.chatId != null) {
      _chatId = widget.chatId!;
    }
  }

  Future<void> _loadAdminId() async {
    final id = await _userService.getAdminId();
    if (id != null && mounted) {
      setState(() => _adminId = id);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_chatId.isNotEmpty && _myId.isNotEmpty) {
      await _chatService.markMessagesAsRead(_chatId, _myId);
    }
  }

  void _finalizeInitialization() {
    if (_adminId.isNotEmpty && _chatId.isNotEmpty) {
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

    // 🔥 Track admin's last message timestamp
    _updateAdminLastMessageTimestamp(snapshot.docs);

    _updatePagedResults(snapshot.docs, currentRequestIndex);
    _emitAllMessages();
    _updatePaginationState(snapshot.docs, currentRequestIndex);
  }

  void _updateAdminLastMessageTimestamp(List<DocumentSnapshot> docs) {
    final adminMessages = docs
        .where((doc) => doc['senderId'] == _adminId)
        .toList()
      ..sort((a, b) =>
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    if (adminMessages.isNotEmpty) {
      final latestTimestamp = adminMessages.first['timestamp'] as Timestamp;
      if (_userLastMessageTimestamp == null ||
          _userLastMessageTimestamp!.compareTo(latestTimestamp) < 0) {
        _userLastMessageTimestamp = latestTimestamp;
      }
    }
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
    if (!_isAdmin) return; // Samo admin šalje poruke

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await _sendMessage(messageText: text);
  }

  Future<void> _sendImageMessage() async {
    if (!_isAdmin) return; // Samo admin šalje poruke

    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _chatService.sendMessage(
        _chatId,
        _adminId,
        _adminId, // Za group chat, admin šalje sam sebi
        '',
        imageFile,
      );
    }
  }

  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    if (_chatId.isEmpty || _adminId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';
    await _chatService.sendMessage(
      _chatId,
      _adminId,
      _adminId, // Za group chat
      message,
      null,
    );
  }

  // ==================== NAVIGATION ====================



  void _navigateToMessageInfo(String messageId) {
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
          if (_isAdmin) _buildMessageInput(),
          if (!_isAdmin) const SizedBox(height: 60), // Spacing za non-admin
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
      appBar: AppBar(title: const Text('Portal BB')),
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
              title:  Text(
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
                GestureDetector(
                  onTap: () => _isAdmin ? _navigateToMessageInfo(messageDoc.id) : {},
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
                  color: isCurrentUser 
                      ? Colors.green[800] 
                      : Colors.brown[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // 🔥 Image (reuse logic from ChatBubble)
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
        // 🔥 Read status - samo ako je admin poslao poruku posle user-ovog pristupa
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