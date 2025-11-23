import 'package:bb_agro_portal/models/create_user.dart';
import 'package:bb_agro_portal/models/fruit_type.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/models/user_fruit_type.dart';
import 'package:bb_agro_portal/screens/users_screen.dart';
import 'package:bb_agro_portal/services/chat_service.dart';
import 'package:bb_agro_portal/services/fruit_types_service.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/shared_ui_components.dart';

class ChangeUserDataScreen extends StatefulWidget {

  final AppUser? appUser;
  const ChangeUserDataScreen({super.key, this.appUser});

  @override
  State<ChangeUserDataScreen> createState() => ChangeUserDataScreenState();
}

class ChangeUserDataScreenState extends State<ChangeUserDataScreen> {
  final UserService _userService = UserService();
  AppUser appUser = AppUser(id: "", name: "", email: "", isActive: false, isPremium: false, city: "", phone: "", isPasswordChangeNeeded: false, fruitTypes: []);


  final FruitTypesService _fruitTypeService = FruitTypesService();
  final ChatService _chatService = ChatService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeteadPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _repeatedPasswordFocusNode = FocusNode();
  final FocusNode _phoneNumberFocusNode = FocusNode();
  final FocusNode _NameFocusNode = FocusNode();
  final FocusNode _CityFocusNode = FocusNode();

  final _formKey = GlobalKey<FormState>();

  List<FruitType> fruitTypes = [];
  String? selectedFruitType;
  final _numberOfTreesController = TextEditingController();
  List<UserFruitType> selectedFruits = <UserFruitType>[];

     @override
  void initState() {
    super.initState();
    if (widget.appUser != null) {
      setState(() {
        appUser = widget.appUser!;

        _nameController.text = appUser.name;

        _phoneNumberController.text = appUser.phone;

        _cityController.text = appUser.city;

        selectedFruits = appUser.fruitTypes;
      });
    }

     _fruitTypeService.retrieveAllFruitTypes().listen((fruitList) {
      setState(() {
        fruitTypes = fruitList;
      });
    });
  }

  Future<void> changeUserData() async {
    await _userService.changeUserData(CreateUserParam(
      id: appUser.id,
      name: _nameController.text,
      email: _nameController.text.toLowerCase().replaceAll(' ', '') + "@agrobb.com",
      password: _passwordController.text,
      city: _cityController.text,
      phone: _phoneNumberController.text,
      fruitTypes: selectedFruits,
    ));

    for (var fruitType in selectedFruits) {
        _chatService.addUserChat(fruitType.fruitTypeId, appUser.id);
      }


    Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserListScreen()),
        );
  }

  Future<void> createNewAccount() async {
    String? userId = await _userService.createNewUser(CreateUserParam(
      id: '',
      name: _nameController.text,
      email: _nameController.text.toLowerCase().replaceAll(' ', '') + "@agrobb.com",
      password: _passwordController.text,
      city: _cityController.text,
      phone: _phoneNumberController.text,
      fruitTypes: selectedFruits,
    ));
    print("Finished adding user");
    print(userId);
    if (userId != null)
    {
      for (var fruitType in selectedFruits) {
        _chatService.addUserChat(fruitType.fruitTypeId, userId);
      }

      String? adminId = await _userService.getAdminId();
      if (adminId != null)
      {
        print("adminId " + adminId);
        String privateChatId = await _generateChatId(adminId, userId);
        print("privateChatId " + privateChatId);
        await _chatService.createNewPrivateChat(privateChatId ,"Private chat");
        await _chatService.addUserChat(privateChatId, userId);
        await _chatService.addUserChat(privateChatId, adminId);

      }
      else
      {
        print('Failed to find admin');
      }
    }

     Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserListScreen()),
        );
  }

  String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite email';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Unesite validan email';
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite šifru';
    }
    if (value.length < 6) {
      return 'Šifra mora imati barem 6 karaktera';
    }
    return null;
  }

  String? repeatedPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo ponovite šifru';
    }
    if (value != _passwordController.text) {
      return 'Šifre se ne poklapaju';
    }
    return null;
  }

  String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite vaše ime';
    }
    return null;
  }

  Future<String> _generateChatId(String user1Id ,String user2Id) async {
      String generatedChatId = '';
      if (user1Id.compareTo(user2Id) < 0) {
          generatedChatId = 'chat_${user1Id}_$user2Id';
        } else {
          generatedChatId = 'chat_${user2Id}_$user1Id';
        }

      return generatedChatId;
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
                title: Text('Izmena podataka', style: TextStyle(color: Colors.white)),
              ),
              Container(height: 3, color: Colors.orangeAccent[400]),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              child: generateHorizontalLine('Osnovne informacije'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Ime",
                controller: _nameController,
                iconData: Icons.person,
                focusNode: _NameFocusNode,
                validator: nameValidator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Broj Telefona",
                controller: _phoneNumberController,
                iconData: Icons.phone,
                focusNode: _phoneNumberFocusNode,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Grad",
                controller: _cityController,
                iconData: Icons.location_city,
                focusNode: _CityFocusNode,
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            //   child: generateTextField(
            //     labelText: "Šifra",
            //     controller: _passwordController,
            //     iconData: Icons.lock,
            //     isPassword: true,
            //     focusNode: _passwordFocusNode,
            //     validator: passwordValidator,
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            //   child: generateTextField(
            //     labelText: "Ponovite šifru",
            //     controller: _repeteadPasswordController,
            //     iconData: Icons.lock,
            //     isPassword: true,
            //     focusNode: _repeatedPasswordFocusNode,
            //     validator: repeatedPasswordValidator,
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              child: generateHorizontalLine('Voćne vrste i broj stabala'),
            ),
            // Primer kako da koristiš u Row

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 50,  // ista visina kao i TextFormField
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green[800]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: selectedFruitType,
                        hint: Text("Voćna vrsta", style: TextStyle(fontSize: 14)),
                        items: fruitTypes.map((fruit) {
                          return DropdownMenuItem<String>(
                            value: fruit.id,
                            child: Text(fruit.name, style: TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedFruitType = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,  // isto
                      child: generateTextField(
                        labelText: "Br. st.",
                        controller: _numberOfTreesController,
                        height: 50, // prosledi height
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    height: 50,  // da dugme bude iste visine ako želiš
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {
                                    if (selectedFruitType != null && _numberOfTreesController.text.isNotEmpty) {
                                      setState(() {
                                        selectedFruits.add(UserFruitType(
                                          fruitTypeId: selectedFruitType!,
                                          fruitTypeName: fruitTypes
                                              .firstWhere((fruit) => fruit.id == selectedFruitType!)
                                              .name,
                                          numberOfTrees: int.parse(_numberOfTreesController.text),
                                        ));
                                        _numberOfTreesController.clear();
                                        selectedFruitType = null;
                                      });
                                    }
                                  },
                      icon: Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedFruits.length,
                itemBuilder: (context, index) {
                  final fruit = selectedFruits[index];
                  final isEven = index % 2 == 0;
                  final controller = TextEditingController(text: fruit.numberOfTrees.toString());

                  return Container(
                    decoration: BoxDecoration(
                      color: isEven ? Colors.grey[200] : Colors.white,
                      border: Border.all(
                        color: Colors.orangeAccent[400] ?? Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Row(
                        children: [
                          // Naziv voćne vrste
                          Expanded(
                            flex: 2,
                            child: Text(
                              fruit.fruitTypeName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),

                          // Polje za unos broja stabala
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Broj stabala',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (value) {
                                  fruit.numberOfTrees = int.tryParse(value) ?? 0;
                              },
                            ),
                          ),

                          // Ikonica za brisanje
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                selectedFruits.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              child: generateButton(
                text: "Sacuvaj izmene",
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    changeUserData();
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
