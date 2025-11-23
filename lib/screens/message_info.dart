import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/services/user_service.dart';

class MessageDetailsScreen extends StatefulWidget {
  final String chatId;
  final String messageId;
  

  const MessageDetailsScreen({
    super.key,
    required this.chatId,
    required this.messageId,// mapa svih usera da dobijemo imena
  });

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
 final UserService _userService = UserService();
  List<Map<String, dynamic>> members = [];
  Map<String, dynamic>? messageData;
  Map<String, AppUser> usersMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Učitaj članove chata
      final membersSnapshot = await _db
          .collection('chats')
          .doc(widget.chatId)
          .collection('members')
          .get();

      members = membersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // 2. Učitaj poruku
      final messageSnapshot = await _db
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(widget.messageId)
          .get();

      messageData = messageSnapshot.data() as Map<String, dynamic>?;

await _loadUsers();
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error loading message details: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _hasMemberRead(String memberId) {
    if (messageData == null) return false;
    List<dynamic> readBy = messageData!['messageReadByUserIds'] ?? [];
    return readBy.contains(memberId);
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
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              'Detalji poruke',
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
      body: ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final memberId = member['userId'];
          String memberName = usersMap[memberId]?.name ?? memberId;
          bool hasRead = _hasMemberRead(memberId);

          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundImage: const AssetImage('assets/images/default_avatar.jpg'),
            ),
            title: Text(
              memberName,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
            ),
            trailing: Icon(
              Icons.remove_red_eye,
              color: hasRead ? Colors.green : Colors.grey,
              size: 18,
            ),
          );
        },
      ),
    );
  }
}
