import 'dart:io';

import 'package:bb_agro_portal/current_user_service.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bb_agro_portal/models/message.dart';
import 'package:bb_agro_portal/services/chat_service.dart';
import 'package:bb_agro_portal/shared_ui_components.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'dart:async';
import 'package:bb_agro_portal/screens/user_details_screen.dart';
import 'package:image_picker/image_picker.dart';


class UserPrivateChatScreen extends StatefulWidget {
  //final String? userId;
  final String? chatId;
  final String? userId;
  const UserPrivateChatScreen({super.key, this.chatId, this.userId});

  @override
  _UserPrivateChatScreenState createState() => _UserPrivateChatScreenState();
}

class _UserPrivateChatScreenState extends State<UserPrivateChatScreen> {
  String adminId = '';
  String chatId = '';
  String userId = '';
  AppUser? admin;
  bool isLoading = true;
  bool isLoadingMessages = false;
  TextEditingController messageTextController = TextEditingController();
  final UserService userService = UserService();
  final ChatService chatService = ChatService();

 final currentUser = CurrentUserService.instance.currentUser;
  // Paginacija
  DocumentSnapshot? _lastDocument;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController(); // ScrollController
  final StreamController<List<DocumentSnapshot>> _chatController =
      StreamController<List<DocumentSnapshot>>.broadcast();
  final List<List<DocumentSnapshot>> _allPagedResults = [<DocumentSnapshot>[]];
  bool _hasMoreData = true;

  Timestamp? userLastMessageTimestamp;
@override
void dispose() {
  _scrollController.dispose();
  _chatController.close();  // Add this line to properly close the StreamController.
  super.dispose();
}
  @override
  void initState() {
    super.initState();
    _initialize();

    

    _scrollController.addListener(() {
      if (_scrollController.offset >=
              (_scrollController.position.maxScrollExtent) &&
          !_scrollController.position.outOfRange) {
       _getChats('scroll');
      }
    });
  }

 Stream<List<DocumentSnapshot>> listenToChatsRealTime() {
    _getChats('liste to chat');
    //return _chatController.stream;
    return _chatController.stream;
  }
  // Initialize data (get adminId and set chatId)
  Future<void> _initialize() async {
    if (widget.userId != null) {
      setState(() {
        userId = widget.userId?.toString() ?? ''; 
      });
    }

    if (widget.chatId != null) {
      setState(() {
        chatId = widget.chatId?.toString() ?? ''; 
      });
    }

    await _getAdminId();

    _loadUser(adminId);
    

    chatService.markMessagesAsRead(chatId, adminId);

    if (adminId.isNotEmpty && userId.isNotEmpty && chatId.isNotEmpty) {
      setState(() {
        isLoading = false; 
      });

   //   _getChats('init');
    }
  }

  Future<void> _getAdminId() async {
    String? id = await userService.getAdminId();
    if (id != null) {
      setState(() {
        adminId = id;
      });
    }
  }

  Future<void> _generateChatId() async {
      String generatedChatId = '';
      if (adminId.compareTo(userId) < 0) {
          generatedChatId = 'chat_${adminId}_$userId';
        } else {
          generatedChatId = 'chat_${userId}_$adminId';
        }

      setState(() {
        chatId = generatedChatId;
      });
  }
  

  // Load messages from Firestore for paginaciju
  Future<void> _loadMessages() async {
    if (isLoadingMessages) return;

    setState(() {
      isLoadingMessages = true;
    });

    QuerySnapshot querySnapshot;

    if (_lastDocument == null) {
      // First load (load most recent messages)
      print(chatId);

      querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true) // Sort descending for latest first
          .limit(20)
          .get();
    } else {
      // Load older messages when scrolling up
      querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true) // Sort descending for latest first
          .startAfterDocument(_lastDocument!)  // Paginate by starting after the last document
          .limit(20)
          .get();
    }

    print("Count: ${querySnapshot.docs.length}");

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        // Add new messages at the top of the list
        _messages.insertAll(_messages.length, querySnapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList());
        _lastDocument = querySnapshot.docs.last;  // Update the last document after loading more
      });
    }

    setState(() {
      isLoadingMessages = false;
    });
  }

  void _getChats(String s) {
    print("get-chats-triggered with id: $s $chatId");
    final CollectionReference chatCollectionReference = FirebaseFirestore
        .instance
        .collection("chats")
        .doc(chatId)
        .collection("messages");
    var pagechatQuery = chatCollectionReference
        .orderBy('timestamp', descending: true)
        .limit(20);

    if (_lastDocument != null) {
      pagechatQuery = pagechatQuery.startAfterDocument(_lastDocument!);
    }

    print(_hasMoreData);

    if (!_hasMoreData) return;

    var currentRequestIndex = _allPagedResults.length;
    
    pagechatQuery.snapshots().listen(
      (snapshot) {
        print(snapshot.docs.length);
        if (snapshot.docs.isNotEmpty) {


          var generalChats = snapshot.docs.toList();

          var userChats = generalChats.where((chat) => chat['senderId'] == userId).toList();

          if (userChats.isNotEmpty) {
            // Sortiraj poruke po timestamp-u, u opadajućem redosledu
            userChats.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

            Map latestMessageData = userChats.first.data() as Map;

            
            // Uzmi najnoviju poruku
            Timestamp latestMessageTimestamp = latestMessageData['timestamp'];

            if (userLastMessageTimestamp == null || userLastMessageTimestamp!.compareTo(latestMessageTimestamp) < 0) {
              userLastMessageTimestamp = latestMessageTimestamp;

              print(latestMessageData['message']);
            }
          }

          var pageExists = currentRequestIndex < _allPagedResults.length;

          if (pageExists) {
            _allPagedResults[currentRequestIndex] = generalChats;
          } else {
            _allPagedResults.add(generalChats);
          }

          var allChats = _allPagedResults.fold<List<DocumentSnapshot>>(
              <DocumentSnapshot>[],
              (initialValue, pageItems) => initialValue..addAll(pageItems));

          _chatController.add(allChats);

          if (currentRequestIndex == _allPagedResults.length - 1) {
            _lastDocument = snapshot.docs.last;
          }

          print(generalChats.length);
          _hasMoreData = generalChats.length == 20;
        }
      },
    );
  }

  // Send message to the chat
  void _sendMessage({String? messageText, String? imageUrl}) {
    if (chatId.isNotEmpty && userId.isNotEmpty) {
      String message = messageText ?? '';
      if (imageUrl != null) {
        message = imageUrl;
      }

      messageTextController.clear();
      chatService.sendMessage(chatId, userId, adminId, message, null);
    }
  }

  // Pick image (implementacija za slike)
  Future<void> _pickImage() async {

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
          chatService.sendMessage(chatId, userId, adminId, "", imageFile);
      }
  }

  void _loadUser(String userId) async {
    print(userId);
    AppUser? dbUser = await userService.getUserById(userId);
    setState(() {
      print(dbUser?.name);
      admin = dbUser;
    });
  }
  @override
  Widget build(BuildContext context){

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (chatId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Portal BB'),
        ),
        body: Center(child: Text('Chat ID nije dostupan.')),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 3),
        child: Container(
          color: Colors.green[800], // Boja pozadine AppBar-a
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Row(
                  children: [
                    SizedBox(width: 30),   
                    GestureDetector(
                      onTap: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserDetailsScreen(userId: adminId),
                          ),
                        );
                      },
                      child: Icon(Icons.account_circle,
                        size: 35)),  // Ikonica
                    SizedBox(width: 8),           // Razmak između ikone i imena
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserDetailsScreen(userId: userId,),
                          ),
                        );
                      },
                      child: Text(admin?.name ?? "", style: TextStyle(color: Colors.white))),
            ],
          ),
              ),
              Container(
                height: 3,
                color: Colors.orangeAccent[400],
              ),
            ],
          ),
        ),
      ),

      
      body: Column(
        children: [
          // Chat with admin
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
                stream:  listenToChatsRealTime(),
                builder: (ctx, chatSnapshot)
                {
                  if (chatSnapshot.connectionState == ConnectionState.waiting ||
                    chatSnapshot.connectionState == ConnectionState.none) {
                      return chatSnapshot.hasData
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : Center(
                          child: Text("Start a Conversation."),
                        );
                   }else {
              if (chatSnapshot.hasData) {
                final chatDocs = chatSnapshot.data!;
                //final user = Provider.of<User?>(context);
                return ListView.builder(
                  controller: _scrollController, // Dodaj ScrollController
                  reverse: true, // Reverse da bi najnovije bile na dnu
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                  Map chatData = chatDocs[index].data() as Map;
                  Timestamp? messageTimestamp = chatData['timestamp'];

                  print('time:');
                  if (messageTimestamp != null){
                    print(messageTimestamp.toDate());

                  }

                  // print(userLastMessageTimestamp?.toDate());
                  // print(chatData['isRead']);
                  //final message = _messages[index];
return Padding(
  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
  child: Row(
    mainAxisAlignment: chatData['senderId'] == adminId
        ? MainAxisAlignment.start
        : MainAxisAlignment.end,
    children: [
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6, // maksimalna širina bubble-a
        ),
        child: IntrinsicWidth(
          stepWidth: 1,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: chatData['senderId'] == adminId
                  ? Colors.orangeAccent[400]
                  : Colors.green[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: chatData['senderId'] == adminId
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (chatData['thumbUrl'] != null || chatData['localImagePath'] != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: Center(
                              child: InteractiveViewer(
                                child: chatData['localImagePath'] != null
                                    ? Image.file(File(chatData['localImagePath']))
                                    : Image.network(chatData['imageUrl']),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: chatData['localImagePath'] != null
                          ? Image.file(
                              File(chatData['localImagePath']),
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : chatData['thumbUrl'] != null
                              ? CachedNetworkImage(
                                  imageUrl: chatData['thumbUrl'],
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 200,
                                    color: Colors.grey,
                                    child: const Icon(Icons.error,
                                        color: Colors.red),
                                  ),
                                )
                              : Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image,
                                      color: Colors.white, size: 50),
                                ),
                    ),
                  ),
                if (chatData['message']?.isNotEmpty ?? false) ...[
                  if (chatData['thumbUrl'] != null ||
                      chatData['localImagePath'] != null)
                    const SizedBox(height: 8),
                  Text(
                    chatData['message'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);

              }
            );
              } else {
                return CircularProgressIndicator();
              }
            }
                })
          
            
            
          ),
          // Input for sending messages

SafeArea(
  child: Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Opacity(
      opacity: currentUser!.isPremium ? 1.0 : 0.6,
      child: AbsorbPointer(
        absorbing: !currentUser!.isPremium,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: generateTextField(
                  labelText: currentUser!.isPremium
                      ? 'Unesite poruku'
                      : 'Niste premium korisnik',
                  controller: messageTextController,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.image),
                color: currentUser!.isPremium ? Colors.blueGrey : Colors.grey,
                onPressed: _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: currentUser!.isPremium ? Colors.orange : Colors.grey,
                onPressed: () {
                  _sendMessage(messageText: messageTextController.text);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  ),
)

        ],
      ),
    );
  }
}

