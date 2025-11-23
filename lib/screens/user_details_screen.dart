import 'dart:io';

import 'package:bb_agro_portal/screens/change_user_data_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:image_picker/image_picker.dart';

class UserDetailsScreen extends StatefulWidget {
  final String? userId;
  const UserDetailsScreen({super.key, this.userId});

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final UserService _userService = UserService();
  AppUser appUser = AppUser(id: "", name: "", email: "", isActive: false, isPremium: false, city: "", phone: "", isPasswordChangeNeeded: false, fruitTypes: []);
  File? _localProfileImage;
  String? thumbUrl = null;
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
    if (dbUser != null && mounted)
    {

      
      final url =  dbUser.thumbUrl;

      setState(() {
        appUser = dbUser;

        _localProfileImage = null;
        
        thumbUrl = url;
      });
    }
  }
 @override
  Widget build(BuildContext context) {
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
              ),
              Container(
                height: 3,
                color: Colors.orangeAccent[400],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Narandžasta pozadina sa borderom sa strane
          Positioned.fill(
            top: MediaQuery.of(context).size.height / 3, // Pozadina počinje od sredine ekrana
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(50, 20)),
                color: Colors.orangeAccent[600] ?? Colors.orange, // Default fallback
                border: Border(
                  top: BorderSide(width: 3, color: Colors.orangeAccent[600] ?? Colors.orange),
                  left: BorderSide(width: 3, color: Colors.orangeAccent[600] ?? Colors.orange),
                  right: BorderSide(width: 3, color: Colors.orangeAccent[600] ?? Colors.orange),
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
    margin: const EdgeInsets.only(top: 20), // pomeraj slike nadole
    alignment: Alignment.center,
    child: Container(
      padding: const EdgeInsets.all(3), // debljina border-a
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.orangeAccent[600] ?? Colors.orange, // boja border-a
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
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: Icon(Icons.error, color: Colors.red),
                      ),
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: Icon(Icons.person, size: 60, color: Colors.white),
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
                      color: Colors.orangeAccent[600] ?? Colors.orange, // Narandžasta boja za border
                      width: 1, // Debljina border-a
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
                      Text(appUser.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                            MaterialPageRoute(builder: (context) => ChangeUserDataScreen(appUser: appUser)),
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
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Text("Vocne vrste", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

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
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green[800],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orangeAccent[400] ?? Colors.orange, width: 2), // Fallback if null
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fruit.fruitTypeName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text("${fruit.numberOfTrees} stabala", style: TextStyle(fontSize: 16, color: Colors.white)),
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
    );
  }
}



