import 'package:fruit_care_pro/models/user.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/models/message.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'dart:async';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'message_info.dart';
class AdminGroupChatScreen extends StatefulWidget {
  final String? userId;
  const AdminGroupChatScreen({super.key, this.userId});

  @override
  _AdminGroupScreenState createState() => _AdminGroupScreenState();
}

class _AdminGroupScreenState extends State<AdminGroupChatScreen> {
  String adminId = '';
  String chatId = '';
  String userId = '';
  AppUser? user;
  bool isLoading = true;
  bool isLoadingMessages = false;
  TextEditingController messageTextController = TextEditingController();
  final UserService userService = UserService();
  final ChatService chatService = ChatService();

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
    _loadUser(userId);
    await _getAdminId();
    await _generateChatId();

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
      chatService.sendMessage(chatId, adminId, userId, message, null);
    }
  }

  // Pick image (implementacija za slike)
  Future<void> _pickImage() async {
    // Code for picking and uploading images (omitted for brevity)
  }

  void _loadUser(String userId) async {
    AppUser? dbUser = await userService.getUserById(userId);
    setState(() {
      user = dbUser;
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
                            builder: (context) => UserDetailsScreen(userId: userId),
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
                      child: Text(user?.name ?? "", style: TextStyle(color: Colors.white))),
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
                  return Align(
                    alignment: chatData['senderId'] == adminId
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                      child: GestureDetector(
                              onTap: () {
                                print('clicked');
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //     builder: (_) => MessageDetailsScreen(
                                //       chatId: chatId,
                                //       messageId: chatData['uid'], // ID poruke koju klikneš
                                //     ),
                                //   ),
                                // );
                              },
                              child: 
                              Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: chatData['senderId'] == adminId ? Colors.orangeAccent[400] : Colors.green[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: chatData['senderId'] == adminId
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                               
                            Text(
                              chatData['message'],
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(height: 5), // Razmak između poruke i ikone
                            // Proveravamo je li poruka posle poslednje poruke koju je korisnik primio
                            if (messageTimestamp != null &&
                            (userLastMessageTimestamp == null 
                            || userLastMessageTimestamp!.compareTo(messageTimestamp) < 0)) ...[
                              // Ikona koja označava pročitanost poruke
                              chatData['isRead'] 
                                  ? Icon(Icons.check_circle, color: Colors.white, size: 16)  // Ikona za pročitanu poruku
                                  : Icon(Icons.check_circle_outline, color: Colors.white, size: 16), // Ikona za nepročitanu poruku
                            ]
                          ],
                        ),
                      )),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: generateTextField(
                    labelText: 'Enter message',
                    controller: messageTextController,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(messageText: messageTextController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

