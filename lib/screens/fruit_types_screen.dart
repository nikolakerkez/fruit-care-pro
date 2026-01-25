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
          title: const Text("Potvrda brisanja"),
          content: Text(
            "Da li ste sigurni da želite da obrišete voćnu vrstu: ${fruitType.name}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Odustani"),
            ),
            TextButton(
              onPressed: () {
                _deleteFruit(fruitType);
                Navigator.of(context).pop();
              },
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
      Navigator.push(
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
                    'Voćne vrste',
                    style: TextStyle(color: Colors.white),
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

  /// Builds bottom navigation bar
  Widget _buildBottomNavigationBar() {
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
        currentIndex: 2,
        selectedItemColor: Colors.brown[500],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2_sharp),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FRUIT LIST ITEM WIDGET
// ============================================================================

/// Individual fruit type list item widget
class _FruitListItem extends StatelessWidget {
  final FruitType fruit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FruitListItem({
    required this.fruit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
                      fruit.name,
                      style: TextStyle(
                        color: Colors.green[800],
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
                icon: Icon(Icons.edit, color: Colors.brown[500]),
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
    );
  }
}