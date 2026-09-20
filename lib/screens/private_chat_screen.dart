import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruit_care_pro/exceptions/chat_exception.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/services/notification_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/widgets/chat_bubble.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';
import 'package:fruit_care_pro/main.dart' show routeObserver;

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

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with WidgetsBindingObserver, RouteAware {
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

  // Reply/edit compose state
  Map<String, dynamic>? _replyingTo; // {messageId, senderName, text}
  String? _editingMessageId;

  // Typing indicator
  Timer? _typingTimer;
  bool _otherUserTyping = false;

  // Pretraga unutar chata
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _searchResults;
  bool _isSearchLoading = false;
  Timer? _searchDebounce;

  // Pagination
  DocumentSnapshot? _lastDocument;
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  final List<StreamSubscription> _subscriptions = [];

  // User state
  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => widget.role == ChatUserRole.admin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // Poziva se kad se korisnik vrati na ovaj screen (back sa sledećeg screena)
  @override
  void didPopNext() {
    if (_chatId.isNotEmpty) {
      NotificationService.setActiveChat(_chatId);
    }
  }

  // Poziva se kad korisnik napusti ovaj screen (otvori novi screen)
  @override
  void didPushNext() {
    NotificationService.clearActiveChat();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onTextChanged);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App ide u background ili je ubijen — obriši activeChatId
      NotificationService.clearActiveChat();
    } else if (state == AppLifecycleState.resumed && _chatId.isNotEmpty) {
      // App se vratio u foreground dok je ovaj chat i dalje na ekranu.
      // initState se NE pokreće ponovo (widget nije uništen minimiziranjem),
      // pa moramo ručno ponoviti ono što bi inače uradio _initializeScreen.
      NotificationService.setActiveChat(_chatId);
      NotificationService.cancelNotificationsForChat(_chatId);
      _markMessagesAsRead();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    // Korisnik napušta chat — obriši activeChatId
    NotificationService.clearActiveChat();

    // Očisti typing status da ne ostane "zaglavljen"
    _typingTimer?.cancel();
    _searchDebounce?.cancel();
    if (_chatId.isNotEmpty && _currentUserId.isNotEmpty) {
      _chatService.setTypingStatus(
        chatId: _chatId,
        userId: _currentUserId,
        isTyping: false,
      );
    }
    _messageController.removeListener(_onTextChanged);

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
    _searchController.dispose();

    super.dispose();
  }

  /// Piše "kuca..." status u Firestore dok korisnik kuca, sa debounce-om
  void _onTextChanged() {
    if (_chatId.isEmpty || _currentUserId.isEmpty) return;

    if (_messageController.text.trim().isNotEmpty) {
      _typingTimer?.cancel();
      _chatService.setTypingStatus(
        chatId: _chatId,
        userId: _currentUserId,
        isTyping: true,
      );
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingStatus(
          chatId: _chatId,
          userId: _currentUserId,
          isTyping: false,
        );
      });
    } else {
      _typingTimer?.cancel();
      _chatService.setTypingStatus(
        chatId: _chatId,
        userId: _currentUserId,
        isTyping: false,
      );
    }
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

      // Cancel notifications for this chat since user is now viewing it
      NotificationService.cancelNotificationsForChat(_chatId);

      // Označi da je korisnik aktivan u ovom chatu → Cloud Function neće slati notifikacije
      NotificationService.setActiveChat(_chatId);

      // Mark messages as read — non-critical, run in background
      _markMessagesAsRead();

      // Prati "kuca..." status drugog korisnika
      _subscriptions.add(
        _chatService.watchChatDoc(_chatId).listen((data) {
          if (!mounted) return;
          final typing = data['typing'] as Map<String, dynamic>?;
          final ts = typing?[_otherUserId] as Timestamp?;
          final isTyping = ts != null &&
              DateTime.now().difference(ts.toDate()) < const Duration(seconds: 8);
          if (isTyping != _otherUserTyping) {
            setState(() => _otherUserTyping = isTyping);
          }
        }),
      );

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

    // Mark all messages as read (individual messages + lastMessage in chat doc).
    // After the first batch write the stream fires once more, but on that second
    // pass nothing is unread so no writes happen and the stream stops re-firing.
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

  /// Send text message (ili sačuvaj izmenu ako je u edit modu)
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      await _saveEditedMessage(text);
      return;
    }

    _messageController.clear();
    final replyTo = _replyingTo;
    setState(() => _replyingTo = null);

    try {
      await _sendMessage(messageText: text, replyTo: replyTo);
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

  /// Sačuvaj izmenjen tekst poruke
  Future<void> _saveEditedMessage(String newText) async {
    final messageId = _editingMessageId;
    if (messageId == null) return;

    _messageController.clear();
    setState(() => _editingMessageId = null);

    try {
      await _chatService.editMessage(
        chatId: _chatId,
        messageId: messageId,
        newText: newText,
      );
    } on SendMessageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to edit message',
        screen: 'PrivateChatScreen',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri izmeni poruke'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Prikaži bottom sheet sa akcijama nad porukom (long-press)
  void _showMessageActions(String messageId, Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return;

    final isOwn = data['senderId'] == _currentUserId;
    final isText = (data['message'] as String?)?.isNotEmpty ?? false;
    final isImage = data['thumbUrl'] != null || data['imageUrl'] != null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Odgovori'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startReply(messageId, data);
                },
              ),
              if (isText)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Kopiraj tekst'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: data['message'] as String));
                  },
                ),
              if (isOwn && isText && !isImage)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Izmeni'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startEdit(messageId, data['message'] as String);
                  },
                ),
              if (isOwn)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Obriši za sve', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteMessage(messageId, forEveryone: true);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Obriši za mene'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteMessage(messageId, forEveryone: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Postavi poruku na koju se odgovara
  void _startReply(String messageId, Map<String, dynamic> data) {
    final isImage = data['thumbUrl'] != null || data['imageUrl'] != null;
    final senderName = data['senderId'] == _currentUserId
        ? 'Ti'
        : (_otherUser?.name ?? 'Korisnik');

    setState(() {
      _editingMessageId = null;
      _replyingTo = {
        'messageId': messageId,
        'senderName': senderName,
        'text': isImage ? '📷 Slika' : (data['message'] as String? ?? ''),
      };
    });
  }

  /// Uđi u edit mod za sopstvenu poruku
  void _startEdit(String messageId, String currentText) {
    setState(() {
      _replyingTo = null;
      _editingMessageId = messageId;
      _messageController.text = currentText;
      _messageController.selection = TextSelection.collapsed(offset: currentText.length);
    });
  }

  /// Otkaži reply/edit stanje
  void _cancelComposerState() {
    setState(() {
      _replyingTo = null;
      if (_editingMessageId != null) {
        _editingMessageId = null;
        _messageController.clear();
      }
    });
  }

  /// Obriši poruku (za sve ili samo za mene)
  Future<void> _deleteMessage(String messageId, {required bool forEveryone}) async {
    try {
      if (forEveryone) {
        await _chatService.deleteMessageForEveryone(chatId: _chatId, messageId: messageId);
      } else {
        await _chatService.deleteMessageForMe(
          chatId: _chatId,
          messageId: messageId,
          userId: _currentUserId,
        );
      }
    } on SendMessageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to delete message',
        screen: 'PrivateChatScreen',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri brisanju poruke'),
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
  Future<void> _sendMessage({
    String? messageText,
    String? imageUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    if (_chatId.isEmpty || _otherUserId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';

    if (replyTo != null) {
      await _chatService.sendMessageToChat(
        chatId: _chatId,
        senderId: _currentUserId,
        messageText: message,
        replyTo: replyTo,
      );
    } else {
      await _chatService.sendMessage(
        _chatId,
        _currentUserId,
        _otherUserId,
        message,
        null,
      );
    }
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
          Expanded(child: _isSearching ? _buildSearchResults() : _buildMessagesList()),
          if (!_isSearching) _buildMessageInput(),
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
      title: _isSearching ? _buildSearchField() : _buildAppBarTitle(),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
        ),
      ],
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
    // Prikaži pravo ime bez obzira na rolu (podržava više admina)
    final displayName = _otherUser?.name ?? (_isAdmin ? 'Korisnik' : 'Admin');

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (_otherUserTyping)
                const Text(
                  'kuca...',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Search input field prikazan u app bar-u dok je pretraga aktivna
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: const InputDecoration(
        hintText: 'Pretraži poruke...',
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      onChanged: _onSearchQueryChanged,
    );
  }

  /// Uključi/isključi pretragu
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = null;
        _searchDebounce?.cancel();
      }
    });
  }

  /// Debounce-ovana pretraga poruka dok korisnik kuca
  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        if (mounted) setState(() => _searchResults = null);
        return;
      }

      if (mounted) setState(() => _isSearchLoading = true);
      final results = await _chatService.searchMessages(chatId: _chatId, query: trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    });
  }

  /// Lista rezultata pretrage
  Widget _buildSearchResults() {
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults == null) {
      return const Center(child: Text('Ukucaj tekst za pretragu poruka.'));
    }
    if (_searchResults!.isEmpty) {
      return const Center(child: Text('Nema rezultata.'));
    }

    final query = _searchController.text.trim();

    return ListView.builder(
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final data = _searchResults![index].data();
        final text = data['message'] as String? ?? '';
        final timestamp = data['timestamp'] as Timestamp?;
        final isMine = data['senderId'] == _currentUserId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2E7D52),
            child: Icon(
              isMine ? Icons.person : Icons.person_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: _buildHighlightedText(text, query),
          subtitle: timestamp != null ? Text(_formatSearchTimestamp(timestamp.toDate())) : null,
          onTap: () => setState(() => _isSearching = false),
        );
      },
    );
  }

  /// Tekst sa podebljanim/istaknutim delom koji se poklapa sa pretragom
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xFFFFF3B0),
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  String _formatSearchTimestamp(DateTime date) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year}. ${pad(date.hour)}:${pad(date.minute)}';
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

        // Sakrij poruke koje je trenutni korisnik obrisao "za mene"
        final messages = snapshot.data!.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? const []);
          return !hiddenFor.contains(_currentUserId);
        }).toList();

        if (messages.isEmpty) {
          return const Center(child: Text('Započnite razgovor.'));
        }

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
                  onLongPress: () => _showMessageActions(messageDoc.id, messageData),
                  child: ChatBubble(
                    messageData: messageData,
                    isCurrentUser: messageData['senderId'] == _currentUserId,
                    otherUserId: _otherUserId,
                    onImageTap: () => _navigateToImageViewer(
                      messageData['imageUrl'] ?? messageData['thumbUrl'],
                      messageData['localImagePath'],
                      messageDoc.id,
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

  /// Build message input field
  Widget _buildMessageInput() {
    // Only regular users need premium check, admin always has access
    final isPremium = _isAdmin ? true : (_currentUser?.isPremium ?? false);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null || _editingMessageId != null) _buildComposerStateBar(),
          Opacity(
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
                        labelText: isPremium ? 'Unesite poruku' : 'Konsultacije nisu aktivne za vaš nalog',
                        controller: _messageController,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildInputButton(Icons.image_outlined, isPremium ? _sendImageMessage : () {}),
                    _buildInputButton(
                      _editingMessageId != null ? Icons.check : Icons.send_rounded,
                      isPremium ? _sendTextMessage : () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Traka iznad input polja koja prikazuje reply/edit kontekst
  Widget _buildComposerStateBar() {
    final isEditing = _editingMessageId != null;
    final title = isEditing ? 'Izmena poruke' : 'Odgovaraš: ${_replyingTo?['senderName'] ?? ''}';
    final subtitle = isEditing ? null : (_replyingTo?['text'] as String?);

    return Container(
      color: const Color(0xFFF0F0F0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(isEditing ? Icons.edit_outlined : Icons.reply, size: 18, color: const Color(0xFF2E7D52)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D52)),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelComposerState,
          ),
        ],
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