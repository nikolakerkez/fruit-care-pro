import 'dart:io';

import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/admin_reset_password_screen.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/change_user_data_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/test_auth_manual.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:image_picker/image_picker.dart';

class UserDetailsScreen extends StatefulWidget {
  final String? userId;
  const UserDetailsScreen({super.key, this.userId});

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final UserService _userService = UserService();
  AppUser appUser = AppUser(
      id: "",
      name: "",
      email: "",
      isActive: false,
      isPremium: false,
      city: "",
      phone: "",
      isPasswordChangeNeeded: false,
      fruitTypes: []);
  File? _localProfileImage;
  String? thumbUrl;

  final AppUser currentUser = CurrentUserService.instance.currentUser!;
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _loadUser(widget.userId ?? "");
    }
  }

  // Pick image (implementacija za slike)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      setState(() {
        _localProfileImage = imageFile;
      });

      await _userService.updateUserProfileImage(appUser.id, imageFile);

      _loadUser(appUser.id);
    }
  }

  void _loadUser(String userId) async {
    AppUser? dbUser = await _userService.getUserDetailsById(userId);

    if (!mounted) return;

    if (dbUser == null) {
      showErrorDialog(context, "Došlo je do greške.");
      return;
    }
    final url = dbUser.thumbUrl;

    setState(() {
      appUser = dbUser;
      _localProfileImage = null;
      thumbUrl = url;
    });
  }

    void _onItemTapped(int index) {
    switch (index) {
      case 0:
        if (currentUser.isAdmin ?? false) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AdminMainScreen()));
        } else {
          print(currentUser.name);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => UserMainScreen()));
        }
        break;
      case 1:
        if (currentUser.isAdmin ?? false) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserListScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AdvertisementCategoriesScreen()),
          );
        }
        break;
      case 2:
        if (currentUser.isAdmin ?? false) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FruitListPage()),
          );
        }
        else
        {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userId: currentUser.id),
          ));
        }
        break;
      case 3:
        if (currentUser.isAdmin ?? false) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AdvertisementCategoriesScreen()),
          );
        }
        break;
    }
  }
  // 🔥 Logout dialog
  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Odjava'),
            ],
          ),
          content: const Text(
            'Da li ste sigurni da želite da se odjavite?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Otkaži',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Odjavi se',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await _performLogout(context);
    }
  }

  // 🔥 Perform logout
  Future<void> _performLogout(BuildContext context) async {
    // Prikaži loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Odjava u toku...'),
          ],
        ),
      ),
    );

    try {
      // Očisti CurrentUserService
      CurrentUserService.instance.clearUser();

      // Zatvori loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen i obriši ceo stack
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', // Zameni sa tvojom login rutom
          (route) => false,
        );
      }
    } catch (e) {
      // Zatvori loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Prikaži error
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Greška'),
              ],
            ),
            content: Text('Došlo je do greške pri odjavi:\n$e'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('U redu'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     final bool isAdmin = CurrentUserService.instance.currentUser?.isAdmin ??
        false; // ili kako već proveravaš

    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Poruke',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Korisnici',
        ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.forest),
          label: 'Voćne vrste',
        ),
      if (isAdmin)
        const BottomNavigationBarItem(
        icon: Icon(Icons.tv),
        label: 'Reklame',
      )
      else
        const BottomNavigationBarItem(
        icon: Icon(Icons.search),
            label: 'Istraži',
        ),
      BottomNavigationBarItem(
            icon: Icon(Icons.person_2_sharp),
            label: 'Profil',
          ),
    ];

    if (appUser.id.isEmpty) {
      // još nisu stigli podaci
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
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
                title: Text(
                  'Korisnički panel',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _showLogoutDialog, // 🔥 Poziv logout dialoga
                  ),
                ],
              ),
              Container(
                height: 3,
                color: Colors.brown[500],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Narandžasta pozadina sa borderom sa strane
          Positioned.fill(
            top: MediaQuery.of(context).size.height /
                3, // Pozadina počinje od sredine ekrana
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(200, 5)),
                color: Colors.green[800] ?? Colors.brown, // Default fallback
                border: Border(
                  top: BorderSide(
                      width: 3, color: Colors.green[800] ?? Colors.brown),
                  left: BorderSide(
                      width: 3, color: Colors.green[800] ?? Colors.brown),
                  right: BorderSide(
                      width: 3, color: Colors.green[800] ?? Colors.brown),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    // TODO: otvori full-screen prikaz slike
                  },
                  child: Container(
                    margin:
                        const EdgeInsets.only(top: 20), // pomeraj slike nadole
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(3), // debljina border-a
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.brown[300] ??
                              Colors.brown, // boja border-a
                          width: 2, // debljina border-a
                        ),
                      ),
                      child: ClipOval(
                        child: _localProfileImage != null
                            ? Image.file(
                                _localProfileImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : appUser.thumbUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: appUser.thumbUrl!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 120,
                                      height: 120,
                                      color: Colors.grey[300],
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 120,
                                      height: 120,
                                      color: Colors.grey[300],
                                      child:
                                          Icon(Icons.error, color: Colors.red),
                                    ),
                                  )
                                : Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: Icon(Icons.person,
                                        size: 60, color: Colors.white),
                                  ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickImage, // klik za izbor nove slike
                  icon: Icon(Icons.edit, size: 20, color: Colors.green[800]),
                  label: Text(
                    "Izmeni sliku",
                    style: TextStyle(color: Colors.green[800], fontSize: 16),
                  ),
                ),

                // Container sa osnovnim informacijama i dugmetom
                Container(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white, // Pozadina za osnovne informacije
                    border: Border.all(
                      color: Colors.brown[300] ??
                          Colors.brown, // Narandžasta boja za border
                      width: 3.1, // Debljina border-a
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Osnovne informacije korisnika
                      Text(appUser.name,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(appUser.phone, style: TextStyle(fontSize: 16)),
                      SizedBox(height: 8),
                      Text(appUser.city, style: TextStyle(fontSize: 16)),
                      SizedBox(height: 20),

                      // Dugme za izmenu profila
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ChangeUserDataScreen(appUser: appUser)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: Size(220, 45),
                        ),
                        child: Text(
                          "Izmeni profil",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      if (currentUser.isAdmin) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AdminResetPasswordScreen(user: appUser)
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[500],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: Size(220, 45),
                        ),
                        child: Text(
                          "Resetuj lozinku",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Text("Vocne vrste",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),

                // Voćne vrste
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Lista voćnih vrsta
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: appUser.fruitTypes.length,
                        itemBuilder: (context, index) {
                          final fruit = appUser.fruitTypes[index];
                          return Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.brown[500],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.brown[300] ?? Colors.brown,
                                  width: 2), // Fallback if null
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fruit.fruitTypeName,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text("${fruit.numberOfTrees} stabala",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.brown[500] ?? Colors.brown,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
            currentIndex: isAdmin ? 4 : 2,
            selectedItemColor: Colors.brown[500],
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: bottomNavItems),
      ),
    );
  }
}
