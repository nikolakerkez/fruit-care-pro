import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/screens/add_update_category.dart';
import 'package:fruit_care_pro/screens/advertisements_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';

class AdvertisementCategoriesScreen extends StatefulWidget {
  const AdvertisementCategoriesScreen({super.key});

  @override
  _AdvertisementCategoriesState createState() =>
      _AdvertisementCategoriesState();
}

class _AdvertisementCategoriesState
    extends State<AdvertisementCategoriesScreen> {
  final AdvertisementService _advertisementService = AdvertisementService();
  final TextEditingController _searchController = TextEditingController();
  final user = CurrentUserService.instance.currentUser;

  String _searchQuery = "";

  void _filterCategories(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _showDeleteDialog(AdvertisementCategory category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Potvrda brisanja"),
          content: Text(
              "Da li ste sigurni da želite da obrišete kategoriju: ${category.name}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Odustani"),
            ),
            TextButton(
              onPressed: () {
                _deleteCategory(category);
                Navigator.of(context).pop();
              },
              child: Text("Obriši"),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(AdvertisementCategory category) {
    _advertisementService.DeleteCategory(category.id);
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        if (user?.isAdmin ?? false) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AdminMainScreen()));
        } else {
          print(user?.name);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => UserMainScreen()));
        }
        break;
      case 1:
        if (user?.isAdmin ?? false) {
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
        if (user?.isAdmin ?? false) {
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
                builder: (context) => UserDetailsScreen(userId: user?.id),
          ));
        }
        break;
      case 3:
        if (user?.isAdmin ?? false) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AdvertisementCategoriesScreen()),
          );
        }
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserDetailsScreen(userId: user?.id))
        );
        break;
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
                title: Row(
                  children: [
                    SizedBox(width: 30),
                    Text('Kategorije', style: TextStyle(color: Colors.white)),
                  ],
                ),
                actions: [
                  if (isAdmin)
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddUpdateCategory(),
                          ),
                        );
                      },
                    )
                ],
              ),
              Container(height: 3, color: Colors.brown[500]),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
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
                    color: Colors.brown[500], // boja kada je fokus
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
                        color: Colors.brown[500]!, // boja kada je fokus
                        width: 2,
                      ))),
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Greška: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('Nema podataka'));
                    }

                    List<AdvertisementCategory> categories = snapshot.data!;
                    final filtered = categories
                        .where((f) => f.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final category = filtered[index];

                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdvertisementsScreen(category: category),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(14),
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
                                    // LEVA STRANA
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                              color: Colors.green[800],
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                        ],
                                      ),
                                    ),

                                    // DESNA STRANA - samo EDIT + DELETE za admina
                                    if (user!.isAdmin) ...[
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: Colors.brown[500]),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AddUpdateCategory(
                                                      category: category),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _showDeleteDialog(category),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.brown[500] ?? Colors.orange,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: user!.isAdmin ? 3 : 1,
          selectedItemColor: Colors.brown[500],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems,
        ),
      ),
    );
  }
}
