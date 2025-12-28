import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/screens/add_update_fruit_type.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';

class FruitListPage extends StatefulWidget {
  const FruitListPage({super.key});

  @override
  _FruitListPageState createState() => _FruitListPageState();
}

class _FruitListPageState extends State<FruitListPage> {
  final FruitTypesService _firestoreService = FruitTypesService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final user = CurrentUserService.instance.currentUser;

  String _searchQuery = "";

  void _filterFruitTypes(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _showDeleteDialog(FruitType fruitType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Potvrda brisanja"),
          content: Text(
              "Da li ste sigurni da želite da obrišete voćnu vrstu: ${fruitType.name}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Odustani"),
            ),
            TextButton(
              onPressed: () {
                _deleteFruit(fruitType);
                Navigator.of(context).pop();
              },
              child: Text("Obriši"),
            ),
          ],
        );
      },
    );
  }

  void _deleteFruit(FruitType fruitType) {
    _firestoreService.deleteFruitType(fruitType.id);
  }

  void _onItemTapped(int index) {

    switch (index) {
      case 0:
            if (user?.isAdmin??false)
            {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => AdminMainScreen()));
            }
            else
            {
              print(user?.name);
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => UserMainScreen()));
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
          MaterialPageRoute(builder: (context) => const AdvertisementCategoriesScreen()),
        );
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
                    Text('Voćne vrste', style: TextStyle(color: Colors.white)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.white),
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
              onChanged: _filterFruitTypes,
              decoration: InputDecoration(
                labelText: "Pretraži voćne vrste",
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
                  ))
              ),
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
                child: StreamBuilder<List<FruitType>>(
                  stream: _firestoreService.retrieveAllFruitTypes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Greška: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('Nema podataka'));
                    }

                    List<FruitType> fruitTypes = snapshot.data!;
                    final filtered = fruitTypes
                        .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final fruit = filtered[index];

                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
                                        SizedBox(height: 4),
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
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddUpdateFruitType(fruitType: fruit),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(fruit),
                                  ),
                                ],
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
      ),
    );
  }
}
