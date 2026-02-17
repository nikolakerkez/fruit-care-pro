import 'package:fruit_care_pro/models/create_user.dart';
import 'package:fruit_care_pro/models/create_user_result.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/models/user_fruit_type.dart';
import 'package:fruit_care_pro/screens/users_screen.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  //Fruit Type Service to fetch all fruit types
  final FruitTypesService _fruitTypeService = FruitTypesService();

  //User service for persisting user
  final UserService _userService = UserService();

  //---Controller for each input ---
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeteadPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  //---Controller for each input ---

  //---FocusNode for each input ---
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _repeatedPasswordFocusNode = FocusNode();
  final FocusNode _phoneNumberFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _cityFocusNode = FocusNode();
  //---FocusNode for each input ---
  final _formKey = GlobalKey<FormState>();

  //Used for storing all fruit types fetched from database
  List<FruitType> fruitTypes = [];

  //Currently selected fruit type - ID
  String? selectedFruitType;

  //Currently entered number of threes
  final _numberOfTreesController = TextEditingController();

  //List of selected fruit types
  List<UserFruitType> selectedFruits = <UserFruitType>[];

  Future<void> createNewAccount() async {
    CreateUserResult createUserResult =
        await _userService.createNewUser(CreateUserParam(
      id: '',
      name: _nameController.text,
      email: "${_nameController.text.toLowerCase().replaceAll(' ', '')}@fruitcarepro.com",
      password: _passwordController.text,
      city: _cityController.text,
      phone: _phoneNumberController.text,
      fruitTypes: selectedFruits,
    ));

    if (createUserResult.isFailed) {
      String errorMessage =
          'Došlo je do greške prilikom kreiranja novog naloga!';

      if (createUserResult.notUniqueUsername) {
        errorMessage = "Postoje korisnik sa istim korisničkim imenom !";
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          Future.delayed(const Duration(seconds: 3), () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.red[800] ?? Colors.red, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const SizedBox(width: 10),
                Flexible(child: Text(errorMessage)),
              ],
            ),
          );
        },
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserListScreen()),
    );
  }

  List<FruitType> GetFruitTypes() {
    final selectedFruitTypeIDs =
        selectedFruits.map((e) => e.fruitTypeId).toSet();

    List<FruitType> returnValue =
        fruitTypes.where((e) => !selectedFruitTypeIDs.contains(e.id)).toList();

    return returnValue;
  }

  @override
  void initState() {
    super.initState();
    _fruitTypeService.retrieveAllFruitTypes().listen((fruitList) {
      setState(() {
        fruitTypes = fruitList;
      });
    });
  }

  String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite email';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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
                title: Text('Dodavanje novog korisnika',
                    style: TextStyle(color: Colors.white)),
              ),
              Container(height: 3, color: Colors.brown[500])
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
                focusNode: _nameFocusNode,
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
                focusNode: _cityFocusNode,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Šifra",
                controller: _passwordController,
                iconData: Icons.lock,
                isPassword: true,
                focusNode: _passwordFocusNode,
                validator: passwordValidator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Ponovite šifru",
                controller: _repeteadPasswordController,
                iconData: Icons.lock,
                isPassword: true,
                focusNode: _repeatedPasswordFocusNode,
                validator: repeatedPasswordValidator,
              ),
            ),
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
                      height: 50, // ista visina kao i TextFormField
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
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
                        initialValue: selectedFruitType,
                        hint:
                            Text("Voćna vrsta", style: TextStyle(fontSize: 14)),
                        items: GetFruitTypes().map((fruit) {
                          return DropdownMenuItem<String>(
                            value: fruit.id,
                            child: Text(fruit.name,
                                style: TextStyle(fontSize: 14)),
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
                      height: 50, // isto
                      child: generateTextField(
                        labelText: "Br. st.",
                        controller: _numberOfTreesController,
                        height: 50, // prosledi height
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    height: 50, // da dugme bude iste visine ako želiš
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (selectedFruitType != null &&
                            _numberOfTreesController.text.isNotEmpty) {
                          setState(() {
                            selectedFruits.add(UserFruitType(
                              fruitTypeId: selectedFruitType!,
                              fruitTypeName: fruitTypes
                                  .firstWhere(
                                      (fruit) => fruit.id == selectedFruitType!)
                                  .name,
                              numberOfTrees:
                                  int.parse(_numberOfTreesController.text),
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isEven ? Colors.grey[100] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green[800]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 20,
                        ),
                        title: Text(
                          fruit.fruitTypeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          "Broj stabala: ${fruit.numberOfTrees}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // 🔥 OVDE DODAJEMO X dugme
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selectedFruits.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateButton(
                text: "Završi dodavanje",
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    createNewAccount();
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
