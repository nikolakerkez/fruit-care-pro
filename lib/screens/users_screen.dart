import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/screens/create_account_screen.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:provider/provider.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<AppUser> users = [];
  List<AppUser> filteredUsers = [];

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final UserService _userService;
  final user = CurrentUserService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _userService = context.read<UserService>();
    _loadUsers();
    _searchController.addListener(_filterUsers);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Učitaj još samo kad nema pretrage i kad smo blizu dna
    if (_searchController.text.isNotEmpty) return;
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isInitialLoading = true);
    final result = await _userService.getAllUsers();
    if (!mounted) return;
    setState(() {
      users = result.users;
      filteredUsers = result.users;
      _lastDoc = result.lastDoc;
      _hasMore = result.users.length == 50;
      _isInitialLoading = false;
    });
  }

  Future<void> _loadMoreUsers() async {
    setState(() => _isLoadingMore = true);
    final result = await _userService.getAllUsers(startAfter: _lastDoc);
    if (!mounted) return;
    setState(() {
      users.addAll(result.users);
      filteredUsers = users;
      _lastDoc = result.lastDoc;
      _hasMore = result.users.length == 50;
      _isLoadingMore = false;
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredUsers = query.isEmpty
          ? users
          : users.where((u) {
              return u.name.toLowerCase().contains(query) ||
                  u.email.toLowerCase().contains(query);
            }).toList();
    });
  }

  Future activateUser(AppUser currentUser) async {
    bool isActionExecuted = await _userService.activateUser(currentUser.id);

    if (!mounted) return;

    if (!isActionExecuted) {
      showErrorDialog(context, "Došlo je do greške.");
      return;
    }

    setState(() {
      currentUser.isActive = true;
    });
  }

  Future deactivateUser(AppUser currentUser) async {
    bool isActionExecuted = await _userService.deactivateUser(currentUser.id);

    if (!mounted) return;

    if (!isActionExecuted) {
      showErrorDialog(context, "Došlo je do greške.");

      return;
    }
    setState(() {
      currentUser.isActive = false;
    });
  }

  Future setPremiumFlag(AppUser currentUser) async {
    bool isActionExecuted = await _userService.setPremiumFlag(currentUser.id);

    if (!mounted) return;

    if (!isActionExecuted) {
      showErrorDialog(context, "Došlo je do greške.");

      return;
    }
    setState(() {
      currentUser.isPremium = true;
    });
  }

  Future removePremiumFlag(AppUser currentUser) async {
    bool isActionExecuted =
        await _userService.removePremiumFlag(currentUser.id);

    if (!mounted) return;

    if (!isActionExecuted) {
      showErrorDialog(context, "Došlo je do greške.");

      return;
    }

    setState(() {
      currentUser.isPremium = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 1) return; // Already on this screen

    switch (index) {
      case 0:
        Navigator.pop(context);
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FruitListPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdvertisementCategoriesScreen()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => UserDetailsScreen(userId: user?.id)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                
                centerTitle: true,
                title: Text(
                  'Korisnici',
                                  ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => CreateAccountScreen()))
                          .then((_) => _loadUsers());
                    },
                  ),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: ColoredBox(color: Color(0xFF2E7D52), child: SizedBox(height: 2, width: double.infinity)),
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
                labelStyle: TextStyle(
                  color: Colors.grey, // boja kada nije fokus
                ),
                floatingLabelStyle: TextStyle(
                  color: const Color(0xFF1A7A30), // boja kada je fokus
                  fontWeight: FontWeight.bold,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey, // boja kada nije fokus
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF1A7A30), // boja kada je fokus
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
              controller: _scrollController,
              itemCount: filteredUsers.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == filteredUsers.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final user = filteredUsers[index];

                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48, // isti width i height → kvadrat
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF66BB6A),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: AspectRatio(
                          aspectRatio: 1,
                          child: user.thumbUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: user.thumbUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Image.asset(
                                      'assets/images/default_avatar.jpg',
                                      fit: BoxFit.cover),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                          'assets/images/default_avatar.jpg',
                                          fit: BoxFit.cover),
                                )
                              : Icon(Icons.person)),
                    ),
                  ),
                  //leading: const Icon(Icons.person),
                  title: Row(
                    children: [
                      Expanded(child: Text(user.name)),
                      GestureDetector(
                        onTap: () {
                          if (user.isPremium) {
                            removePremiumFlag(user);
                          } else {
                            setPremiumFlag(user);
                          }
                        },
                        child: Icon(
                          Icons.star,
                          color: user.isPremium
                              ? const Color(0xFF1A7A30)
                              : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: user.isActive,
                    onChanged: (value) async {
                      if (value) {
                        activateUser(user);
                      } else {
                        deactivateUser(user);
                      }
                    },
                    activeThumbColor: const Color(0xFF1A7A30), // kružić kada je uključen
                    inactiveThumbColor:
                        const Color(0xFF1A7A30), // kružić kada je isključen
                    activeTrackColor:
                        Colors.grey[300], // track kada je uključen
                    inactiveTrackColor: Colors.grey[300],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(
                          userId: user.id,
                          activeBottomNavIndex: 1,
                        ),
                      ),
                    ).then((_) => _loadUsers());
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(

        currentIndex: 1,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF388E3C),
        unselectedItemColor: Colors.grey[400],
        elevation: 8,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2_sharp),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
