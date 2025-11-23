import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/screens/advertisements_screen.dart';
import 'package:bb_agro_portal/services/chat_service.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'users_screen.dart';
import 'package:bb_agro_portal/admin_fruit_types_board.dart';
import 'package:bb_agro_portal/current_user_service.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';

class AdminMainScreen extends StatefulWidget {
  final AppUser? adminUser;
  const AdminMainScreen({super.key, this.adminUser});

  @override
  _AdminMainScreenState createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final int _selectedIndex = 0;
    Map<String, AppUser> usersMap = <String, AppUser>{};

  AppUser? adminUser;
  final user = CurrentUserService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.adminUser != null) {
      setState(() {
        adminUser = widget.adminUser;
      });
    }

    await _loadUsers();
  }

Future<void> _loadUsers() async {
  var allUsers = await _userService.getAllUsers();
  setState(() {
    usersMap = 
    {
      for (var user in allUsers) user.id: user
    };
  });
}
void _onItemTapped(int index) {

    switch (index) {
      case 0:
            if (user?.isAdmin??false)
            {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => AdminMainScreen(adminUser: user)));
            }
            else
            {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => UserMainScreen(appUser: user)));
            }
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserListScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FruitListPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdvertisementsScreen()),
        );
        break;
    }
  }


 Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 3),
        child: Container(
          color: Colors.green[800],
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: const Text(
                  'Poruke',
                  style: TextStyle(color: Colors.white),
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
      body: StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('chats')
      .where('memberIds', arrayContains: adminUser?.id)
      .orderBy('lastMessageTimestamp', descending: true)
      .snapshots(),
  builder: (context, chatSnapshot) {
    if (!chatSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    var chats = chatSnapshot.data!.docs;

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        var chat = chats[index];
        var chatData = chat.data() as Map<String, dynamic>;

        bool isGroup = chatData['type'] == "group";
        String chatTitle = chatData['name'] ?? "Nepoznat chat";

        // Stream za člana koji je trenutno ulogovan
        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('chats')
              .doc(chat.id)
              .collection('members')
              .doc(adminUser?.id)
              .snapshots(),
          builder: (context, memberSnapshot) {
            if (!memberSnapshot.hasData) {
              return const ListTile(title: Text("Loading..."));
            }

            var memberData = memberSnapshot.data!.data() as Map<String, dynamic>?;

            var lastMessageMap = memberData?['lastMessage'] as Map<String, dynamic>?;
            String lastMessage = lastMessageMap?['message'] ?? "";
            DateTime lastMessageTimestamp =
                (lastMessageMap?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            bool isLastMessageRead = (lastMessageMap?['read'] ?? false) || lastMessage == "-" ;

            // Ako je privatni chat, dohvatimo ime drugog korisnika

            String otherUserId = '';
            String? thumbUrl = null;
            if (!isGroup && chatData['memberIds'] != null) {
              var memberIds = (chatData['memberIds'] as List);
              
              otherUserId = memberIds.firstWhere(
                (m) => m != adminUser?.id,
                orElse: () => {},
              );

              // Ovde možeš pozvati mapu svih usera da dohvatiš ime
              chatTitle = usersMap[otherUserId]?.name ?? 'Nepoznat korisnik';

              thumbUrl = usersMap[otherUserId]?.thumbUrl;
            }

            String truncatedMessage = lastMessage.length > 30
                ? '${lastMessage.substring(0, 30)}...'
                : lastMessage;

            return ListTile(
              leading: Container(
                width: 60,
                height: 60, // isti width i height → kvadrat
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orangeAccent[700] ?? Colors.orange,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1, // garantuje da slika ostane kvadratna
                    child: thumbUrl != null
                            ? CachedNetworkImage(
                                imageUrl: thumbUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Image.asset('assets/images/default_avatar.jpg', fit: BoxFit.cover),
                                errorWidget: (context, url, error) =>
                                    Image.asset('assets/images/default_avatar.jpg', fit: BoxFit.cover),
                              )
                            : Image.asset('assets/images/default_avatar.jpg', fit: BoxFit.cover)),
                  ),
                ),
              title: Text(
                chatTitle,
                style: TextStyle(
                    fontWeight: isLastMessageRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    truncatedMessage,
                    style: TextStyle(
                        fontWeight: isLastMessageRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  Text(
                    timeago.format(lastMessageTimestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              //trailing: Icon(Icons.arrow_forward, color: Colors.orangeAccent[400], size: isLastMessageRead ? 24 : 28),
              onTap: () {
                if (isGroup) {
                  Navigator.pushNamed(
                    context,
                    '/group-chat',
                    arguments: {
                      'chatId': chat.id,
                      'fruitTypeId': chat.id,
                      'fruitTypeName': chatData['name'],
                    },
                  );
                } else {
                  Navigator.pushNamed(
                              context,
                              '/admin-private-chat',
                              arguments: {
                                'chatId': chat.id,
                                'userId': otherUserId
                              },
                            );
                }
              },
            );
          },
        );
      },
    );
  },
),


      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.orangeAccent[400] ?? Colors.orange,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          selectedItemColor: Colors.green[800],
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
          ],
        ),
      ),
    );
  }
}

          