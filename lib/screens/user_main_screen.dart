import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/screens/advertisements_screen.dart';
import 'package:bb_agro_portal/services/chat_service.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'admin_private_chat_screen.dart';
import 'users_screen.dart';
import 'package:bb_agro_portal/admin_fruit_types_board.dart';
import 'package:bb_agro_portal/current_user_service.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';
import 'package:bb_agro_portal/screens/admin_main_screen.dart';

class UserMainScreen extends StatefulWidget {
  final AppUser? appUser;
  const UserMainScreen({super.key, this.appUser});

  @override
  _UserMainScreenState createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final int _selectedIndex = 0;
  Map<String, AppUser> usersMap = <String, AppUser>{};
  final user = CurrentUserService.instance.currentUser;

  AppUser? appUser;

  @override
  void initState() {
    super.initState();
    _initialize();

  }

  Future<void> _initialize() async {
    if (widget.appUser != null) {
      setState(() {
        appUser = widget.appUser;
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
          MaterialPageRoute(builder: (context) => const AdvertisementsScreen()),
        );
        break;
    }
  }


  @override
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
      .where('memberIds', arrayContains: appUser?.id)
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
              .doc(appUser?.id)
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
            if (!isGroup && chatData['memberIds'] != null) {
              var memberIds = (chatData['memberIds'] as List);
              
              var otherUserId = memberIds.firstWhere(
                (m) => m != appUser?.id,
                orElse: () => {},
              );

              // Ovde možeš pozvati mapu svih usera da dohvatiš ime
              chatTitle = usersMap[otherUserId]?.name ?? 'Nepoznat korisnik';
            }

            String truncatedMessage = lastMessage.length > 30
                ? lastMessage.substring(0, 30) + '...'
                : lastMessage;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: const AssetImage('assets/images/default_avatar.jpg'),
                radius: 34,
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
                    '/person-private-chat',
                    arguments: {
                      'chatId': chat.id,
                      'userId': appUser?.id,
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
              icon: Icon(Icons.tv),
              label: 'Reklame',
            ),
          ],
        ),
      ),
    );
  }
}
