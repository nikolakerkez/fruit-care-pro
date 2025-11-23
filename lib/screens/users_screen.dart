import 'package:bb_agro_portal/admin_fruit_types_board.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:bb_agro_portal/screens/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/screens/user_details_screen.dart';
import 'package:bb_agro_portal/screens/admin_main_screen.dart';
import 'package:bb_agro_portal/current_user_service.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<AppUser> users = [];
  List<AppUser> filteredUsers = [];
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final user = CurrentUserService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  // Load users from the database
  void _loadUsers() async {
    List<AppUser>? dbUsers = await _userService.getAllUsers();

    setState(() {
      users = dbUsers;
      filteredUsers = dbUsers; // Initially, show all users
    });
    }

  // Filter users based on search input
  void _filterUsers() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      filteredUsers = users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future activateUser(AppUser currentUser) async
  {
      await _userService.activateUser(currentUser.id);
      setState(() {
            currentUser.isActive = true;
      });
  }

  Future deactivateUser(AppUser currentUser) async
  {
    await _userService.deactivateUser(currentUser.id);
      setState(() {
            currentUser.isActive = false;
      });
  }

Future setPremiumFlag(AppUser currentUser) async
  {
      await _userService.setPremiumFlag(currentUser.id);
      setState(() {
            currentUser.isPremium = true;
      });
  }

  Future removePremiumFlag(AppUser currentUser) async
  {
    await _userService.removePremiumFlag(currentUser.id);
      setState(() {
            currentUser.isPremium = false;
      });
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              print(user?.name);
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
          MaterialPageRoute(builder: (context) => const UserListScreen()),
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
                title: Text(
                  'Korisnici',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateAccountScreen()));
                    },
                  ),
                ],
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pretraži korisnike',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = filteredUsers[index];

                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Row(
                    children: [
                      Expanded(child: Text(user.name)),
                      GestureDetector(
                        onTap: () {
                          if (user.isPremium)
                          {
                            removePremiumFlag(user);
                          }
                          else
                          {
                             setPremiumFlag(user);
                          }
                        },
                        child: Icon(
                          Icons.star,
                          color: user.isPremium ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: user.isActive,
                    onChanged: (value) async {
                      if (value)
                      {
                        activateUser(user);
                      }
                      else
                      {
                        deactivateUser(user);
                      }

                    },
                    activeColor: Colors.green,
                  ),
                  onTap: () {
                    // Navigate to the UserDetailsScreen with the selected userId
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(userId: user.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
          currentIndex: 1,
          selectedItemColor: Colors.green[800],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
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
