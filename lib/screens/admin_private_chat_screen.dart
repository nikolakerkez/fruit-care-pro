import 'dart:io';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'dart:async';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:image_picker/image_picker.dart';

class AdminPrivateChatScreen extends StatefulWidget {
  final String? chatId;
  final String? userId;

  const AdminPrivateChatScreen({
    super.key,
    this.chatId,
    this.userId,
  });

  @override
  State<AdminPrivateChatScreen> createState() => _AdminPrivateChatScreenState();
}

class _AdminPrivateChatScreenState extends State<AdminPrivateChatScreen> {
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
  String _adminId = CurrentUserService.instance.currentUser!.id;
  String _chatId = '';
  String _userId = '';
  AppUser? _user;
  bool _isLoading = true;
  bool _hasMoreData = true;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  Timestamp? _userLastMessageTimestamp;
  final List<StreamSubscription> _subscriptions = [];
  AppUser? get _currentUser => CurrentUserService.instance.currentUser;

 @override
  void initState() {
    debugPrint('🚀 ========================================');
    debugPrint('🚀 UserPrivateChatScreen initState STARTED');
    debugPrint('🚀 widget.chatId: ${widget.chatId}');
    debugPrint('🚀 widget.userId: ${widget.userId}');
    debugPrint('🚀 ========================================');

    super.initState();
    _initialize();
    _setupScrollListener();
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing UserPrivateChatScreen...');

    // ✅ 1. PRVO otkaži SVE Firestore listenere
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // ✅ 2. ONDA zatvori stream controller
    _chatStreamController.close();

    // ✅ 3. Na kraju dispozuj controllers
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

// ==================== INITIALIZATION ====================

  Future<void> _initialize() async {
    await _extractRouteParameters();
    await _loadUser();
    await _markMessagesAsRead();
    _finalizeInitialization();
  }

  Future<void> _extractRouteParameters() async {
    if (widget.userId != null) {
      _userId = widget.userId!;
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

  Future<void> _loadUser() async {
    if (_adminId.isEmpty) return;

    final user = await _userService.getUserById(_userId);
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_chatId.isNotEmpty && _adminId.isNotEmpty) {
      await _chatService.markMessagesAsRead(_chatId, _adminId);
    }
  }

  void _finalizeInitialization() {
    debugPrint('🔍 === INITIALIZATION CHECK ===');
    debugPrint('   adminId: "$_adminId" (empty: ${_adminId.isEmpty})');
    debugPrint('   userId: "$_userId" (empty: ${_userId.isEmpty})');
    debugPrint('   chatId: "$_chatId" (empty: ${_chatId.isEmpty})');

    if (_adminId.isNotEmpty && _userId.isNotEmpty && _chatId.isNotEmpty) {
      debugPrint('✅ All IDs present - setting isLoading to false');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      debugPrint('❌ Missing IDs - staying in loading state');
      debugPrint('   Will show loading screen');
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
    return _scrollController.offset >=
        _scrollController.position.maxScrollExtent;
  }

  // ==================== CHAT LOADING ====================

  Stream<List<DocumentSnapshot>> _listenToChatsRealTime() {
    _loadMoreMessages();
    return _chatStreamController.stream;
  }

void _loadMoreMessages() {
  debugPrint('🔄 _loadMoreMessages called');
  debugPrint('   _hasMoreData: $_hasMoreData');
  debugPrint('   _chatId: "$_chatId"');
  
  if (!_hasMoreData) {
    debugPrint('⚠️ No more data to load');
    return;
  }

  if (_chatId.isEmpty) {
    debugPrint('❌ Cannot load messages - chatId is empty!');
    return;
  }

  final query = _buildMessagesQuery();
  final currentRequestIndex = _allPagedResults.length;

  debugPrint('📥 Loading messages batch #$currentRequestIndex from chat: $_chatId');

  final subscription = query.snapshots().listen(
    (snapshot) {
      debugPrint('📨 Snapshot received: ${snapshot.docs.length} docs');
      _handleMessagesSnapshot(snapshot, currentRequestIndex);
    },
    onError: (error) => debugPrint('❌ Error loading messages: $error'),
  );

  _subscriptions.add(subscription);
  debugPrint('✅ Subscription added (total: ${_subscriptions.length})');
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

  void _handleMessagesSnapshot(
    QuerySnapshot snapshot,
    int currentRequestIndex,
  ) {
    // ✅ KRITIČNO: Proveri mounted status
    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, ignoring snapshot');
      return;
    }

    if (snapshot.docs.isEmpty) {
      debugPrint('⚠️ Empty snapshot - no more messages');

      // ✅ Proveri da li je stream još otvoren
      if (!_chatStreamController.isClosed) {
        _chatStreamController.add([]);
      }

      setState(() => _hasMoreData = false);
      return;
    }

    debugPrint('✅ Received ${snapshot.docs.length} messages');

    _updateUserLastMessageTimestamp(snapshot.docs);
    _updatePagedResults(snapshot.docs, currentRequestIndex);
    _emitAllMessages();
    _updatePaginationState(snapshot.docs, currentRequestIndex);
  }

  void _emitAllMessages() {
    final allMessages = _allPagedResults.expand((page) => page).toList();
    _chatStreamController.add(allMessages);
  }

  void _updateUserLastMessageTimestamp(List<DocumentSnapshot> docs) {
    final userMessages = docs
        .where((doc) => doc['senderId'] == _adminId)
        .toList()
      ..sort((a, b) =>
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    if (userMessages.isNotEmpty) {
      final latestTimestamp = userMessages.first['timestamp'] as Timestamp;
      if (_userLastMessageTimestamp == null ||
          _userLastMessageTimestamp!.compareTo(latestTimestamp) < 0) {
        _userLastMessageTimestamp = latestTimestamp;
      }
    }
  }

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

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await _sendMessage(messageText: text);
  }

  Future<void> _sendImageMessage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _chatService.sendMessage(
        _chatId,
        _adminId,
        _userId,
        '',
        imageFile,
      );
    }
  }

  Future<void> _sendMessage({String? messageText, String? imageUrl}) async {
    if (_chatId.isEmpty || _userId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';
    await _chatService.sendMessage(
      _chatId,
      _adminId,
      _userId,
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
          child: _buildAvatarContent(thumbUrl),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String? thumbUrl) {
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

  Widget _buildAppBarTitle() {
    return Row(
      children: [
        const SizedBox(width: 30),
        GestureDetector(
          onTap: () => _navigateToUserDetails(_userId),
          child: _buildAvatar(_user?.thumbUrl),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _navigateToUserDetails(_userId),
          child: Text(
            _user?.name ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
        ),
      ],
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
          
          // 🔥 Proveri da li treba prikazati datum separator
          final showDateSeparator = _shouldShowDateSeparator(
            messages,
            index,
          );

          return Column(
            children: [
              // Prikaži datum separator ako je potrebno
              if (showDateSeparator)
                DateSeparator(
                  timestamp: messageData['timestamp'] as Timestamp?,
                ),
              
              // Prikaži poruku
              _ChatBubble(
                messageData: messageData,
                isCurrentUser: messageData['senderId'] != _userId,
                userId: _userId,
                onImageTap: () => _navigateToImageViewer(
                  messageData['imageUrl'] ?? messageData['thumbUrl'],
                  messageData['localImagePath'],
                  messageData['messageId'], // 🔥 Prosleđuj messageId
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
  // Uvek prikaži separator za poslednju (najstariju) poruku
  if (index == messages.length - 1) return true;

  final currentMessage = messages[index].data() as Map<String, dynamic>;
  final nextMessage = messages[index + 1].data() as Map<String, dynamic>;

  final currentTimestamp = currentMessage['timestamp'] as Timestamp?;
  final nextTimestamp = nextMessage['timestamp'] as Timestamp?;

  if (currentTimestamp == null || nextTimestamp == null) return false;

  final currentDate = currentTimestamp.toDate();
  final nextDate = nextTimestamp.toDate();

  // Prikaži separator ako su poruke iz različitih dana
  return !_isSameDay(currentDate, nextDate);
}

// 🔥 Helper metoda - proveri da li su isti dan
bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}
  Widget _buildMessageInput() {

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: 1.0,
          child: AbsorbPointer(
            absorbing: false,
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
        ),
      ),
    );
  }
}

// ==================== EXTRACTED WIDGETS ====================

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isCurrentUser;
  final VoidCallback? onImageTap;
  final String userId;
  
  const _ChatBubble({
    required this.messageData,
    required this.isCurrentUser,
    required this.userId,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: isCurrentUser ? Colors.green[600] : Colors.brown[500],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (_hasImage) _buildImage(),
                    if (_hasText) ...[
                      if (_hasImage) const SizedBox(height: 8),
                      _buildText(),
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

  bool get _hasImage =>
      messageData['thumbUrl'] != null || 
      messageData['localImagePath'] != null ||
      messageData['isUploading'] == true;

  bool get _hasText => (messageData['message'] as String?)?.isNotEmpty ?? false;

Widget _buildImage() {
  final isUploading = messageData['isUploading'] ?? false;
  final uploadFailed = messageData['uploadFailed'] ?? false;
  final uploadProgress = (messageData['uploadProgress'] ?? 0.0) as double;
  final hasThumb = messageData['thumbUrl'] != null;

  // Prikaži loader SAMO ako nema thumbnail-a
  if (isUploading && !hasThumb) {
    return _buildUploadingImage(uploadProgress);
  }

  // Prikaži error SAMO ako nema ni thumb
  if (uploadFailed && !hasThumb) {
    return _buildFailedImage();
  }

  final messageId = messageData['messageId'] as String?;

  // Prikaži sliku BEZ mini loadera
  return GestureDetector(
    onTap: onImageTap,
    child: Hero(
      tag: 'image_$messageId', // 🔥 Unique tag
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(),
      ),
    ),
  );
  // ❌ UKLONI Stack sa mini loader-om
}

// 🔥 Loading state sa progress bar-om
Widget _buildUploadingImage(double progress) {
  final localPath = messageData['localImagePath'] as String?;
  
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 200,
      // ❌ UKLONI width: double.infinity jer si unutar IntrinsicWidth
      child: Stack(
        children: [
          // Prikaži lokalnu sliku (blur)
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
          
          // Loading overlay
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progress > 0 
                      ? '${(progress * 100).toInt()}%'
                      : 'Učitavanje...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 🔥 Failed state - takođe ukloni width
Widget _buildFailedImage() {
  return Container(
    height: 200,
    // ❌ UKLONI width: double.infinity
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // TODO: Implementiraj retry logiku
            print('Retry upload');
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Pokušaj ponovo'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[700],
          ),
        ),
      ],
    ),
  );
}
Widget _buildImageWidget() {
  final thumbUrl = messageData['thumbUrl'] as String?;
  final localPath = messageData['localImagePath'] as String?;

  // 🔥 Uvek prikaži samo THUMBNAIL u chat-u
  if (thumbUrl != null) {
    return CachedNetworkImage(
      imageUrl: thumbUrl,
      height: 200,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }

  if (localPath != null) {
    return Image.file(
      File(localPath),
      height: 200,
      fit: BoxFit.cover,
    );
  }

  return _buildDefaultImage();
}

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      color: Colors.grey,
      child: const Icon(Icons.error, color: Colors.red),
    );
  }

  Widget _buildDefaultImage() {
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
        // Prikaži kukice samo za poruke trenutnog korisnika
        if (isCurrentUser) ...[
          const SizedBox(width: 4),
          _buildReadStatusIcon(),
        ],
      ],
    );
  }

  Widget _buildReadStatusIcon() {
    final readBy = messageData['readBy'] as Map<String, dynamic>? ?? {};

    final isReadByOther = readBy.containsKey(userId);
    // Dve plave kukice ako je pročitano
    if (isReadByOther) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 16,
            color: Colors.blue[300], // Plava boja za pročitano
          ),
        ],
      );
    }
    // Dve sive kukice ako je isporučeno ali ne pročitano
    return Icon(
      Icons.done_all,
      size: 16,
      color: Colors.white.withOpacity(0.6), // Siva za isporučeno
    );
  }

  Widget _buildText() {
    return Text(
      messageData['message'],
      style: const TextStyle(color: Colors.white),
    );
  }
}
