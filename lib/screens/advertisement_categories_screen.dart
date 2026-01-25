import 'package:flutter/material.dart';
import 'package:fruit_care_pro/exceptions/advertisement_exception.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/add_update_category.dart';
import 'package:fruit_care_pro/screens/advertisements_screen.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:provider/provider.dart';

class AdvertisementCategoriesScreen extends StatefulWidget {
  const AdvertisementCategoriesScreen({super.key});

  @override
  _AdvertisementCategoriesState createState() =>
      _AdvertisementCategoriesState();
}

class _AdvertisementCategoriesState
    extends State<AdvertisementCategoriesScreen> {
  // Services
  late final AdvertisementService _advertisementService;

  // State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // User
  late final user = CurrentUserService.instance.currentUser;
  bool get _isAdmin => user?.isAdmin ?? false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    
    _advertisementService = context.read<AdvertisementService>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Updates search query and triggers rebuild
  void _filterCategories(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// Shows confirmation dialog before deleting category
  void _showDeleteDialog(AdvertisementCategory category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Potvrda brisanja"),
          content: Text(
            "Da li ste sigurni da želite da obrišete kategoriju: ${category.name}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Odustani"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCategory(category);
              },
              child: const Text("Obriši"),
            ),
          ],
        );
      },
    );
  }

  /// Deletes category from Firestore
  Future<void> _deleteCategory(AdvertisementCategory category) async {
    try {
      await _advertisementService.deleteCategory(category.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategorija "${category.name}" je uspešno obrisana'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DeleteCategoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Neočekivana greška pri brisanju kategorije'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles bottom navigation bar item tap
  void _onItemTapped(int index) {
    // Calculate actual index based on visible items
    final actualIndex = _calculateActualIndex(index);

    // Don't navigate if already on current tab
    if ((_isAdmin && actualIndex == 3) || (!_isAdmin && actualIndex == 1)) {
      return;
    }

    Widget? destination;

    switch (actualIndex) {
      case 0: // Poruke
        destination =
            _isAdmin ? const AdminMainScreen() : const UserMainScreen();
        break;
      case 1: // Korisnici (admin) / Istraži (user)
        if (_isAdmin) {
          destination = const UserListScreen();
        } else {
          destination = const AdvertisementCategoriesScreen();
        }
        break;
      case 2: // Voćne vrste (admin) / Profil (user)
        if (_isAdmin) {
          destination = const FruitListPage();
        } else {
          destination = UserDetailsScreen(userId: user?.id);
        }
        break;
      case 3: // Reklame (admin only)
        if (_isAdmin) {
          destination = const AdvertisementCategoriesScreen();
        }
        break;
      case 4: // Profil (admin only)
        destination = UserDetailsScreen(userId: user?.id);
        break;
    }

    if (destination != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination!),
      );
    }
  }

  /// Calculates actual navigation index based on visible items
  int _calculateActualIndex(int visibleIndex) {
    if (!_isAdmin) {
      // For users: [Poruke(0), Istraži(1), Profil(2)]
      // Map to: [0, 1, 4]
      return visibleIndex == 0
          ? 0
          : visibleIndex == 1
              ? 1
              : 4;
    }
    // For admins, visible index matches actual index
    return visibleIndex;
  }

  /// Navigates to category details screen
  void _navigateToCategoryDetails(AdvertisementCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvertisementsScreen(category: category),
      ),
    );
  }

  /// Navigates to add/edit category screen
  void _navigateToAddEditCategory([AdvertisementCategory? category]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUpdateCategory(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Builds app bar with title and add button
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 3),
      child: Container(
        color: Colors.green[800],
        child: Column(
          children: [
            AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: const Row(
                children: [
                  SizedBox(width: 30),
                  Text(
                    'Kategorije',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _navigateToAddEditCategory(),
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
    );
  }

  /// Builds main body with search field and categories list
  Widget _buildBody() {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(child: _buildCategoriesList()),
      ],
    );
  }

  /// Builds search text field
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _searchController,
        onChanged: _filterCategories,
        decoration: InputDecoration(
          labelText: "Pretraži kategorije",
          labelStyle: TextStyle(color: Colors.green[800]),
          prefixIcon: Icon(Icons.search, color: Colors.green[800]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          floatingLabelStyle: TextStyle(
            color: Colors.brown[500],
            fontWeight: FontWeight.bold,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.grey,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.brown[500]!,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds categories list with StreamBuilder
  Widget _buildCategoriesList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(6),
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StreamBuilder<List<AdvertisementCategory>>(
          stream: _advertisementService.retrieveAllCategories(),
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error state
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Greška: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}), // Rebuild to retry
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              );
            }

            // Empty state
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nema kategorija',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Success state - filter and display categories
            final categories = snapshot.data!;
            final filtered = categories
                .where((f) =>
                    f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();

            // No results after filtering
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nema rezultata pretrage',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final category = filtered[index];
                return _CategoryListItem(
                  category: category,
                  isAdmin: _isAdmin,
                  onTap: () => _navigateToCategoryDetails(category),
                  onEdit: () => _navigateToAddEditCategory(category),
                  onDelete: () => _showDeleteDialog(category),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Builds bottom navigation bar
  Widget _buildBottomNavigationBar() {
    final bottomNavItems = _buildBottomNavItems();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.brown[500] ?? Colors.orange,
            width: 1.0,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _isAdmin ? 3 : 1,
        selectedItemColor: Colors.brown[500],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: bottomNavItems,
      ),
    );
  }

  /// Builds bottom navigation items based on user role
  List<BottomNavigationBarItem> _buildBottomNavItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Poruke',
      ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Korisnici',
        )
      else
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Istraži',
        ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.forest),
          label: 'Voćne vrste',
        ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.tv),
          label: 'Reklame',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_2_sharp),
        label: 'Profil',
      ),
    ];
  }
}

// ============================================================================
// CATEGORY LIST ITEM WIDGET
// ============================================================================

/// Individual category list item widget
class _CategoryListItem extends StatelessWidget {
  final AdvertisementCategory category;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryListItem({
    required this.category,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green[800] ?? Colors.orange,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                // Edit and Delete buttons - only for admins
                if (isAdmin) ...[
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.brown[500]),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
