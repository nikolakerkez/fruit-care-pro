import 'dart:io';

import 'package:fruit_care_pro/models/advertisement.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/models/create_user.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/models/user_fruit_type.dart';
import 'package:fruit_care_pro/screens/advertisement_categories_screen.dart';
import 'package:fruit_care_pro/screens/advertisements_screen.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/documents_service.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:image_picker/image_picker.dart';

class CreateAdvertisementScreen extends StatefulWidget {
  final AdvertisementCategory category;
  const CreateAdvertisementScreen({super.key, required this.category});

  @override
  State<CreateAdvertisementScreen> createState() => CreateAdvertisementState();
}

class CreateAdvertisementState extends State<CreateAdvertisementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  AdvertisementCategory? category = null;
  File? _localProfileImage;
  String? thumbUrl = null;
  String? imageUrl = null;
  String? thumbPath = null;
  String? imagePath = null;
  String? localImagePath = null;
  final FocusNode _NameFocusNode = FocusNode();

  final _formKey = GlobalKey<FormState>();
  final AdvertisementService _advertisementService = AdvertisementService();

  Future<void> createNewAdvertisement() async {
    print ('create advertisement');

    await _advertisementService.AddNewAdvertisement(Advertisement(
      id: '',
      imageUrl: imageUrl!,
      thumbUrl: thumbUrl!,
      imagePath: imagePath!,
      thumbPath: thumbPath!,
      localImagePath: localImagePath!,
      name: _nameController.text,
      description: _descriptionController.text,
      url: _urlController.text,
      categoryRefId: category!.id
    ));

     Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdvertisementCategoriesScreen()),
        );
  }

  @override
  void initState() {
    super.initState();

    setState(() {
      category = widget.category;
      print(category!.id);
    });
  }

  String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite vaše ime';
    }
    return null;
  }

 Future<void> _pickImage() async {

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      
      setState(() {
        _localProfileImage = imageFile;
      });
      
      Map<String, String>? uploadImageResult = await uploadImage(imageFile, "reklama.jpg");

      imagePath = uploadImageResult?["fullPath"];

       thumbPath = uploadImageResult?['thumbPath'];

       imageUrl = uploadImageResult?["fullUrl"];

       thumbUrl = uploadImageResult?['thumbUrl'];

       localImagePath = imageFile.path;
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
                title: Text('Dodavanje nove reklame', style: TextStyle(color: Colors.white)),
              ),
              Container(height: 3, color: Colors.brown[500]),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [
            SizedBox(height: 20),
            Container(
      padding: const EdgeInsets.all(3), // debljina border-a
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        border: Border.all(
          color: Colors.brown[500] ?? Colors.brown, // boja border-a
          width: 2, // debljina border-a
        ),
      ),
      child: ClipRect(
        child: _localProfileImage != null
            ? Image.file(
                _localProfileImage!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
            : thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl!,
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
                  SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickImage, // klik za izbor nove slike
                icon: Icon(Icons.edit, size: 20, color: Colors.green[800]),
                label: Text(
                  "Izmeni sliku",
                  style: TextStyle(color: Colors.green[800], fontSize: 16),
                ),
              ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Naziv",
                controller: _nameController,
                iconData: Icons.person,
                focusNode: _NameFocusNode,
                validator: nameValidator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Link ka sajtu",
                controller: _urlController,
                iconData: Icons.link,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Opis",
                controller: _descriptionController,
                iconData: Icons.description,
                minLines: 1,
                maxLines: 10
                
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              child: generateButton(
                text: "Završi dodavanje",
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    createNewAdvertisement();
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
  }
