import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/exceptions/chat_exception.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/widgets/date_separator.dart';
import 'package:fruit_care_pro/screens/message_info.dart';
import 'package:fruit_care_pro/screens/full_screen_image_viewer.dart';
import 'package:fruit_care_pro/services/notification_service.dart';
import 'package:fruit_care_pro/main.dart' show routeObserver;

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

class _GroupChatScreenState extends State<GroupChatScreen>
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
  late final String _myId;
  String _adminId = '';
  String _chatId = '';
  String _fruitTypeId = '';
  String _fruitTypeName = '';
  bool _isLoading = true;
  bool _hasMoreData = true;
  String? _errorMessage;

  // Reply/edit compose state
  Map<String, dynamic>? _replyingTo; // {messageId, senderName, text}
  String? _editingMessageId;

  // Typing indicator (samo admin piše, ostali samo gledaju)
  Timer? _typingTimer;
  bool _adminTyping = false;

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
  Timestamp? _userLastMessageTimestamp;

  // Visibility cutoff — non-admin users only see messages from this timestamp onwards
  Timestamp? _messagesVisibleFrom;

  // User state
  AppUser? get _currentUser => CurrentUserService.instance.currentUser;
  bool get _isAdmin => _currentUser?.isAdmin ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    if (_chatId.isNotEmpty) {
      NotificationService.setActiveChat(_chatId);
    }
  }

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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
    if (_chatId.isNotEmpty && _isAdmin) {
      _chatService.setTypingStatus(
        chatId: _chatId,
        userId: _myId,
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

  /// Piše "kuca..." status u Firestore dok admin kuca, sa debounce-om
  void _onTextChanged() {
    if (_chatId.isEmpty || !_isAdmin) return;

    if (_messageController.text.trim().isNotEmpty) {
      _typingTimer?.cancel();
      _chatService.setTypingStatus(chatId: _chatId, userId: _myId, isTyping: true);
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingStatus(chatId: _chatId, userId: _myId, isTyping: false);
      });
    } else {
      _typingTimer?.cancel();
      _chatService.setTypingStatus(chatId: _chatId, userId: _myId, isTyping: false);
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
      _myId = currentUser.id;

      // Get services from Provider
      _userService = context.read<UserService>();
      _chatService = context.read<ChatService>();

      // Extract route parameters
      await _extractRouteParameters();

      // Load admin ID (with timeout to prevent hanging)
      await _loadAdminId().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Timeout pri učitavanju admin podataka'),
      );

      // Load visibility cutoff for non-admin users
      await _loadMessagesVisibleFrom();

      // Otkaži notifikacije za ovaj chat i umanji badge counter
      NotificationService.cancelNotificationsForChat(_chatId);

      // Označi da je korisnik aktivan u ovom chatu → Cloud Function neće slati notifikacije
      NotificationService.setActiveChat(_chatId);

      // Mark messages as read — non-critical, run in background
      _markMessagesAsRead();

      // Prati "kuca..." status admina (samo ne-admin gledaoci ovo prate,
      // pošto niko drugi ne piše u ovom chatu)
      if (!_isAdmin) {
        _subscriptions.add(
          _chatService.watchChatDoc(_chatId).listen((data) {
            if (!mounted) return;
            final typing = data['typing'] as Map<String, dynamic>?;
            final ts = typing?[_adminId] as Timestamp?;
            final isTyping = ts != null &&
                DateTime.now().difference(ts.toDate()) < const Duration(seconds: 8);
            if (isTyping != _adminTyping) {
              setState(() => _adminTyping = isTyping);
            }
          }),
        );
      }

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

    // Ako naziv nije prosleđen (npr. otvoreno iz notifikacije),
    // dohvati ga iz chat dokumenta
    if (_fruitTypeName.isEmpty) {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .get();
      if (chatDoc.exists) {
        _fruitTypeName = chatDoc.data()?['name'] as String? ?? '';
        if (_fruitTypeId.isEmpty) {
          _fruitTypeId = _chatId;
        }
      }
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

  /// Load the timestamp from which messages are visible for the current user.
  /// Admin sees all messages; regular users only see messages from when they joined.
  Future<void> _loadMessagesVisibleFrom() async {
    if (_isAdmin) return; // admin sees everything

    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('members')
          .doc(_myId)
          .get();

      if (memberDoc.exists) {
        _messagesVisibleFrom = memberDoc.data()?['messagesVisibleFrom'] as Timestamp?;
      }
    } catch (e) {
      // Non-critical — if it fails, user sees all messages
    }
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

    if (_messagesVisibleFrom != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: _messagesVisibleFrom);
    }

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

  /// Emit all messages to stream while marking them as read
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
    if (!_isAdmin) {
      _showAdminOnlyMessage();
      return;
    }

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
        screen: 'GroupChatScreen',
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

    final isOwn = _isAdmin && data['senderId'] == _myId;
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
              if (_isAdmin)
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

    setState(() {
      _editingMessageId = null;
      _replyingTo = {
        'messageId': messageId,
        'senderName': _fruitTypeName,
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
          userId: _myId,
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
        screen: 'GroupChatScreen',
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
  Future<void> _sendMessage({
    String? messageText,
    String? imageUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    if (_chatId.isEmpty || _adminId.isEmpty) return;

    final message = messageText ?? imageUrl ?? '';

    if (replyTo != null) {
      await _chatService.sendMessageToChat(
        chatId: _chatId,
        senderId: _adminId,
        messageText: message,
        replyTo: replyTo,
      );
    } else {
      await _chatService.sendMessage(
        _chatId,
        _adminId,
        _adminId, // For group chat
        message,
        null,
      );
    }
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
          Expanded(child: _isSearching ? _buildSearchResults() : _buildMessagesList()),
          if (!_isSearching && _isAdmin) _buildMessageInput(),
          if (!_isSearching && !_isAdmin) const SizedBox(height: 60),
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

  Widget _buildAppBarTitle() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2E7D52),
          ),
          child: const Icon(Icons.groups, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fruitTypeName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!_isAdmin && _adminTyping)
              const Text(
                'kuca...',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
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

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF2E7D52),
            child: Icon(Icons.campaign_outlined, color: Colors.white, size: 18),
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
          return !hiddenFor.contains(_myId);
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
                  onTap: () => _isAdmin
                      ? _navigateToMessageInfo(messageDoc.id)
                      : null,
                  onLongPress: () => _showMessageActions(messageDoc.id, messageData),
                  child: _GroupChatBubble(
                    messageData: messageData,
                    isCurrentUser: messageData['senderId'] == _myId,
                    isAdmin: _isAdmin,
                    userLastMessageTimestamp: _userLastMessageTimestamp,
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

  /// Build message input field (admin only)
  Widget _buildMessageInput() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null || _editingMessageId != null) _buildComposerStateBar(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: generateTextField(
                    labelText: 'Unesite poruku',
                    controller: _messageController,
                  ),
                ),
                const SizedBox(width: 4),
                _buildInputButton(Icons.image_outlined, _sendImageMessage),
                _buildInputButton(
                  _editingMessageId != null ? Icons.check : Icons.send_rounded,
                  _sendTextMessage,
                ),
              ],
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
    if (_isDeleted) {
      return _buildDeletedPlaceholder();
    }

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
                  gradient: isCurrentUser
                      ? const LinearGradient(
                          colors: [Color(0xFF1B3A2D), Color(0xFF2E7D52)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isCurrentUser ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isCurrentUser
                      ? null
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (_replyTo != null) _buildReplyQuote(),

                    // Image
                    if (hasImage) _buildImage(),

                    // Text message
                    if (_hasText) ...[
                      if (hasImage) const SizedBox(height: 8),
                      Text(
                        messageData['message'],
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white : const Color(0xFF1A1A1A),
                          fontSize: 15,
                        ),
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

  bool get _isDeleted => messageData['isDeleted'] == true;

  bool get _isEdited => messageData['isEdited'] == true;

  Map<String, dynamic>? get _replyTo =>
      messageData['replyTo'] as Map<String, dynamic>?;

  Widget _buildDeletedPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Poruka je obrisana',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote() {
    final replyTo = _replyTo!;
    final senderName = replyTo['senderName'] as String? ?? '';
    final text = replyTo['text'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: isCurrentUser ? Colors.white70 : const Color(0xFF2E7D52),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? Colors.white : const Color(0xFF2E7D52),
            ),
          ),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isCurrentUser
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

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
      return CachedNetworkImage(
        imageUrl: thumbUrl,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.white, size: 50),
        ),
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
        if (_isEdited) ...[
          Text(
            'izmenjeno · ',
            style: TextStyle(
              color: isCurrentUser ? Colors.white.withValues(alpha: 0.7) : Colors.black45,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        Text(
          formattedTime,
          style: TextStyle(
            color: isCurrentUser ? Colors.white.withValues(alpha: 0.7) : Colors.black45,
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