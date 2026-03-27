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
import 'package:cached_network_image/cached_network_image.dart';
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
  double? _uploadProgress;

  final AppUser currentUser = CurrentUserService.instance.currentUser!;
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _loadUser(widget.userId ?? "");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      setState(() {
        _localProfileImage = imageFile;
        _uploadProgress = 0.0;
      });

      await _userService.updateUserProfileImage(
        appUser.id,
        imageFile,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      if (mounted) setState(() => _uploadProgress = null);

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
      await _userService.logout();

      // Očisti CurrentUserService
      CurrentUserService.instance.clearUser();

      // Zatvori loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen i obriši ceo stack
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
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
                  backgroundColor: const Color(0xFF388E3C),
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

  Widget _buildAvatarImage() {
    if (_localProfileImage != null) {
      return Image.file(_localProfileImage!,
          width: 96, height: 96, fit: BoxFit.cover);
    }
    if (appUser.thumbUrl != null) {
      return CachedNetworkImage(
        imageUrl: appUser.thumbUrl!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.person, size: 44, color: Colors.white70),
      );
    }
    return const Icon(Icons.person, size: 44, color: Colors.white70);
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6B7280), size: 22),
      title: Text(label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      subtitle: Text(
        value.isNotEmpty ? value : '—',
        style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w500),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: ColoredBox(color: Color(0xFF2E7D52), child: SizedBox(height: 2, width: double.infinity)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile header (dark green banner) ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B3A2D), Color(0xFF2E7D52)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(child: _buildAvatarImage()),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B3A2D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_uploadProgress != null) ...[
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    appUser.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statusBadge(
                        appUser.isActive ? 'Aktivan' : 'Neaktivan',
                        appUser.isActive
                            ? const Color(0xFF388E3C)
                            : Colors.red[300]!,
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(
                        appUser.isPremium ? 'Premium' : 'Standard',
                        appUser.isPremium
                            ? const Color(0xFFFFB300)
                            : Colors.grey[400]!,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Card(
                    child: Column(
                      children: [
                        _infoTile(
                            Icons.phone_outlined, 'Telefon', appUser.phone),
                        const Divider(indent: 56, height: 1),
                        _infoTile(
                            Icons.location_city_outlined, 'Grad', appUser.city),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Actions
                  generateButton(
                    text: 'Izmeni profil',
                    icon: Icons.edit_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ChangeUserDataScreen(appUser: appUser)),
                    ),
                  ),
                  if (currentUser.isAdmin) ...[
                    const SizedBox(height: 10),
                    generateButton(
                      text: 'Resetuj lozinku',
                      icon: Icons.lock_reset_outlined,
                      backgroundColor: const Color(0xFF1A7A30),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AdminResetPasswordScreen(user: appUser)),
                      ),
                    ),
                  ],

                  // Fruit types
                  if (appUser.fruitTypes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Voćne vrste',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF388E3C),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...appUser.fruitTypes.map(
                      (fruit) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.forest,
                                color: Color(0xFF388E3C), size: 20),
                          ),
                          title: Text(
                            fruit.fruitTypeName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            '${fruit.numberOfTrees} stabala',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: isAdmin ? 4 : 2,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF388E3C),
        unselectedItemColor: Colors.grey[400],
        elevation: 8,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: bottomNavItems,
      ),
    );
  }
}
