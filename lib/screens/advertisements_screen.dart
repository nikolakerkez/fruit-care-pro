import 'dart:async';

import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/create_update_advertisement_screen.dart';
import 'package:fruit_care_pro/screens/fruit_types_screen.dart';
import 'package:fruit_care_pro/models/advertisement.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/widgets/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:provider/provider.dart';

class AdvertisementsScreen extends StatefulWidget {
  final AdvertisementCategory category;
  final String? initialAdvertisementId;
  const AdvertisementsScreen(
      {super.key, required this.category, this.initialAdvertisementId});

  @override
  State<AdvertisementsScreen> createState() => _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends State<AdvertisementsScreen> {
  List<Advertisement> advertisements = [];
  final user = CurrentUserService.instance.currentUser;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  late final AdvertisementService _advertisementService;
  int _currentPage = 0;
  Timer? _autoSlideTimer;
  AdvertisementCategory? category;
  @override
  void initState() {
    super.initState();

    _advertisementService = context.read<AdvertisementService>();

    setState(() {
      category = widget.category;
    });

    _loadAdvertisements(category!.id);
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

  
Future<void> _showDeleteDialog(Advertisement ad) async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 10),
            const Text('Potvrda brisanja'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Da li ste sigurni da želite da obrišete reklamu:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              '"${ad.name}"',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ova akcija se ne može opozvati.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Otkaži',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              _deleteAdvertisement(ad);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Obriši',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteAdvertisement(Advertisement ad) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    await _advertisementService.deleteAdvertisement(ad.id);

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reklama "${ad.name}" je uspešno obrisana'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _loadAdvertisements(category!.id);

  } catch (e) {

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    await ErrorLogger.logError(
      e,
      StackTrace.current,
      reason: 'Failed to delete advertisement',
      screen: 'AdvertisementsScreen._deleteAdvertisement',
      additionalData: {
        'advertisement_id': ad.id,
        'advertisement_name': ad.name,
      },
    );
  }
}

  void _loadAdvertisements(String categoryId) async {
    List<Advertisement>? dbAdvertisements =
        await _advertisementService.getAllAdvertisementsForCategory(categoryId);

    setState(() {
      advertisements = dbAdvertisements;
    });

    if (widget.initialAdvertisementId != null) {
      final index = advertisements
          .indexWhere((ad) => ad.id == widget.initialAdvertisementId);

      if (index != -1 && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(index);
            setState(() {
              _currentPage = index;
            });
          }
        });
      }
    }
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        if (user?.isAdmin ?? false) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => AdminMainScreen()));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => UserMainScreen()));
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
        } else {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin =
        CurrentUserService.instance.currentUser?.isAdmin ?? false;

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
                title: Text(
                  category!.name,
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  if (isAdmin)
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CreateUpdateAdvertisementScreen(
                                category: category!)));
                      },
                    ),
                  if (isAdmin && advertisements.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CreateUpdateAdvertisementScreen(
                                category: category!,
                                advertisement: advertisements[_currentPage])));
                      },
                    ),
                  if (isAdmin && advertisements.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.white),
                      onPressed: () {
                        _showDeleteDialog(advertisements[_currentPage]);
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
                  height: 320, 
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
                  clipBehavior: Clip
                      .hardEdge, 
                  child: Column(
                    children: [
                   
                      Expanded(
                        flex: 6,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: Image.network(
                            ad.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Name
                              Text(
                                ad.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
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

                              if (_currentPage == index)
                                Text(
                                  ad.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black54),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
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

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(advertisements.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.green[800]
                      : Colors.grey[400],
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
              color: Colors.brown[500] ?? Colors.brown,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
            currentIndex: isAdmin ? 3 : 1,
            selectedItemColor: Colors.brown[500],
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: bottomNavItems),
      ),
    );
  }
}
