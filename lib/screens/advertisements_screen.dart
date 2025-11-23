import 'dart:async';

import 'package:bb_agro_portal/admin_fruit_types_board.dart';
import 'package:bb_agro_portal/models/advertisement.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/screens/change_advertisement_screen.dart';
import 'package:bb_agro_portal/screens/create_advertisement_screen.dart';
import 'package:bb_agro_portal/screens/users_screen.dart';
import 'package:bb_agro_portal/services/advertisement_service.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:bb_agro_portal/screens/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/screens/user_details_screen.dart';
import 'package:bb_agro_portal/screens/admin_main_screen.dart';
import 'package:bb_agro_portal/current_user_service.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';

class AdvertisementsScreen extends StatefulWidget {
  const AdvertisementsScreen({super.key});

  @override
  State<AdvertisementsScreen> createState() => _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends State<AdvertisementsScreen> {
  List<Advertisement> advertisements = [];
  final AdvertisementService _advertisementService = AdvertisementService();
  final user = CurrentUserService.instance.currentUser;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _loadAdvertisements();
  }

  void _startAutoSlide() {
      _autoSlideTimer?.cancel();
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (advertisements.isNotEmpty && _pageController.hasClients) {
          int nextPage = (_currentPage + 1) % advertisements.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    @override
    void dispose() {
      _pageController.dispose();
      _autoSlideTimer?.cancel();
      super.dispose();
    }
  // Load users from the database
  void _loadAdvertisements() async {
    List<Advertisement>? dbAdvertisements= await _advertisementService.getAllAdvertisements();
     
    setState(() {
      advertisements = dbAdvertisements;
    });
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
       if (user?.isAdmin ?? false)
       {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserListScreen()),
        );
       }
       else
       {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdvertisementsScreen()),
        );
       }
        break;
      case 2:
        if (user?.isAdmin ?? false)
        {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FruitListPage()),
        );}
        break;
      case 3:
      if (user?.isAdmin ?? false)
      {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdvertisementsScreen()),
        );
      }
        break;
    }
  }

  
  @override
  Widget build(BuildContext context) {

      final bool isAdmin = CurrentUserService.instance.currentUser?.isAdmin ?? false; // ili kako već proveravaš

  // napravi listu item-a dinamički
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
    const BottomNavigationBarItem(
      icon: Icon(Icons.tv),
      label: 'Reklame',
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
                title: Text(
                  'Reklame',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [ if (isAdmin)
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateAdvertisementScreen()));
                    },
                  ),
                  if (isAdmin)
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChangeAdvertisementScreen(advertisement:  advertisements[_currentPage])));
                    },
                  ),
                  if (isAdmin)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CreateAdvertisementScreen()));
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
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: advertisements.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final ad = advertisements[index];
return AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOut,
  margin: EdgeInsets.symmetric(
    horizontal: 8,
    vertical: _currentPage == index ? 10 : 25,
  ),
  height: 320, // Fiksna visina karte — ključno za stabilnost
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: Colors.white,
    boxShadow: const [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 6,
        offset: Offset(0, 3),
      )
    ],
  ),
  clipBehavior: Clip.hardEdge, // sprečava da sadržaj "procuri" tokom animacije
  child: Column(
    children: [
      // Slika zauzima fiksovani deo visine preko Expanded
      Expanded(
        flex: 6,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.network(
            ad.imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
          ),
        ),
      ),

      // Donji deo (tekst) - fleksibilan i sigurno ograničen
      Expanded(
        flex: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Name
              Text(
                ad.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // URL
              GestureDetector(
                onTap: () {
                  print("Otvaram link: ${ad.url}");
                },
                child: Text(
                  ad.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 6),

              // Description: prikazuje se *u okviru* rezervisanog prostora;
              // ne uklanja se iz layouta, nego je ograničen da ne pravi overflow.
              // Ako želiš da u pozadini nema description, možeš umesto ovog
              // prikazati SizedBox.shrink(); ovde koristimo ograničenje.
              if (_currentPage == index)
                // aktivna karta: može prikazati više linija, ali i dalje ograničeno
                Text(
                  ad.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                )
              else
                // neaktivne karte: uopšte ne prikazujemo description (zauzima minimalno mesto)
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    ],
  ),
);



            },
          ),
        ),
        const SizedBox(height: 10),

        // Indikatori (tačkice)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(advertisements.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    _currentPage == index ? Colors.green[800] : Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
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
          currentIndex: isAdmin ? 3 : 1,
          selectedItemColor: Colors.green[800],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems
        ),
      ),
    );
  }
}
