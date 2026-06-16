import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/exceptions/fruit_types_exception.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/add_update_fruit_type.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:provider/provider.dart';

class FruitListPage extends StatefulWidget {
  const FruitListPage({super.key});

  @override
  _FruitListPageState createState() => _FruitListPageState();
}

class _FruitListPageState extends State<FruitListPage> {
  // Services
  late final FruitTypesService _fruitTypesService;  
  // State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // User
  late final user = CurrentUserService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fruitTypesService = context.read<FruitTypesService>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Updates search query and triggers rebuild
  void _filterFruitTypes(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// Shows confirmation dialog before deleting fruit type
  void _showDeleteDialog(FruitType fruitType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Potvrda brisanja"),
          content: Text(
            "Da li ste sigurni da želite da obrišete voćnu vrstu: ${fruitType.name}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Odustani", style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteFruit(fruitType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Obriši"),
            ),
          ],
        );
      },
    );
  }

  /// Deletes fruit type from Firestore
  Future<void> _deleteFruit(FruitType fruitType) async {
    try {
      await _fruitTypesService.deleteFruitType(fruitType.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voćna vrsta "${fruitType.name}" je uspešno obrisana'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DeleteFruitTypeException catch (e) {
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
            content: Text('Neočekivana greška pri brisanju voćne vrste'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handles bottom navigation bar item tap
  void _onItemTapped(int index) {
    // Don't navigate if already on current tab
    if (index == 2) return;

    final routes = <Widget>[
      user?.isAdmin ?? false 
        ? const AdminMainScreen() 
        : const UserMainScreen(), // Index 0
      const UserListScreen(), // Index 1
      const FruitListPage(), // Index 2 - current screen
      const AdvertisementCategoriesScreen(), // Index 3
      UserDetailsScreen(userId: user?.id), // Index 4
    ];

    if (index < routes.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => routes[index]),
      );
    }
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
    return AppBar(
              
              title: const Row(
                children: [
                  SizedBox(width: 30),
                  Text(
                    'Voćne vrste',
                                      ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddUpdateFruitType(),
                      ),
                    );
                  },
                ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: ColoredBox(color: Color(0xFF2E7D52), child: SizedBox(height: 2, width: double.infinity)),
              ),
            );
  }

  /// Builds main body with search field and fruit list
  Widget _buildBody() {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(child: _buildFruitList()),
      ],
    );
  }

  /// Builds search text field
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _searchController,
        onChanged: _filterFruitTypes,
        decoration: InputDecoration(
          labelText: "Pretraži voćne vrste",
          labelStyle: TextStyle(color: const Color(0xFF388E3C)),
          prefixIcon: Icon(Icons.search, color: const Color(0xFF388E3C)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          floatingLabelStyle: TextStyle(
            color: const Color(0xFF1A7A30),
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
              color: const Color(0xFF1A7A30),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds fruit types list with StreamBuilder
  Widget _buildFruitList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(6),
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StreamBuilder<List<FruitType>>(
          stream: _fruitTypesService.retrieveAllFruitTypes(),
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
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                      Icons.forest_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nema voćnih vrsta',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Success state - filter and display fruit types
            final fruitTypes = snapshot.data!;
            final filtered = fruitTypes
                .where((f) => f.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
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
                final fruit = filtered[index];
                return _FruitListItem(
                  fruit: fruit,
                  onTap: () => _showFruitTypeUsers(fruit),
                  onEdit: () => _navigateToEditScreen(fruit),
                  onDelete: () => _showDeleteDialog(fruit),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Navigates to edit fruit type screen
  void _navigateToEditScreen(FruitType fruit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUpdateFruitType(fruitType: fruit),
      ),
    );
  }

  /// Shows bottom sheet with users for the given fruit type
  void _showFruitTypeUsers(FruitType fruit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.forest, color: Color(0xFF388E3C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fruit.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF388E3C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Korisnici ove voćne vrste',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fruitTypesService.getUsersForFruitType(fruit.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data ?? [];

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Nema korisnika za ovu voćnu vrstu',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final u = users[index];
                          final name = u['name'] as String;
                          final numberOfTrees = u['numberOfTrees'] as int;
                          final thumbUrl = u['thumbUrl'] as String?;

                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF66BB6A),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: thumbUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Image.asset(
                                          'assets/images/default_avatar.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                        errorWidget: (_, __, ___) => Image.asset(
                                          'assets/images/default_avatar.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/images/default_avatar.jpg',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF388E3C)),
                              ),
                              child: Text(
                                '$numberOfTrees stabala',
                                style: const TextStyle(
                                  color: Color(0xFF388E3C),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds bottom navigation bar
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 2,
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
    );
  }
}

// ============================================================================
// FRUIT LIST ITEM WIDGET
// ============================================================================

/// Individual fruit type list item widget
class _FruitListItem extends StatelessWidget {
  final FruitType fruit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FruitListItem({
    required this.fruit,
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
        child: GestureDetector(
          onTap: onTap,
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF388E3C),
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
                      fruit.name,
                      style: TextStyle(
                        color: const Color(0xFF388E3C),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Broj stabala po hektaru: ${fruit.numberOfTreesPerAre}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: const Color(0xFF1A7A30)),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}