import 'package:fruit_care_pro/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/shared_ui_components.dart'; // Popravio sam grešku u importu (dva tačka)
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:provider/provider.dart';
import 'package:fruit_care_pro/user_notifier.dart';
import 'package:fruit_care_pro/current_user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //---Credentials text controllers---
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  //---Credentials text controllers---

  //Service for login
  final UserService _userService = UserService();

  //Form key for validation
  final _formKey = GlobalKey<FormState>();
  String errorInfo = "";

  //---Credential Focus nodes for validation---
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  //---Credential Focus nodes for validation---

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(() {
      if (_usernameFocusNode.hasFocus) {
        setState(() {
          //Reset validator
        });
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setState(() {
          // Reset validator
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite korisninčko ime';
    }
    // final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    // if (!emailRegex.hasMatch(value)) {
    //   return 'Unesite validan email';
    // }
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    String username = _usernameController.text;
    String password = _passwordController.text;
    String email = "$username@fruitcarepro.com";
    errorInfo = "";

    AppUser? appUser = await _userService.login(email, password);

    if (!mounted) return;

    //1. User does not exist, show corresponding message
    if (appUser == null) {
      setState(() {
        errorInfo = "Ne postoji korisnik. Pokušajte ponovo.";
      });
      return;
    }

    //2. User account is not activated, show corresponding message
    if (!appUser.isActive) {
      setState(() {
        errorInfo =
            "Vaš nalog nije više aktivan, kontaktirajte administratora..";
      });
      return;
    }

    Provider.of<UserNotifier>(context, listen: false).setUser(appUser);
    CurrentUserService.instance.setCurrentUser(appUser);

    //3. If this is first login, password change is needed, forward to change password screen
    if (appUser.isPasswordChangeNeeded) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ChangePasswordScreen(appUser: appUser)));

      return;
    }

    //4. If user is administrator, forward to admin main screen
    if (appUser.isAdmin) {
      // If it is admin forward to the admin main screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminMainScreen()),
      );

      return;
    }

    //5. If it is regular user forward to the regular user main screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserMainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Fruit care pro',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 3,
                color: Colors.brown[500],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey, // Povezivanje Form sa ključem
          child: Column(
            children: [
              Container(
                color: Colors.transparent, // Postavite pozadinsku boju na belu
                padding:
                    EdgeInsets.all(30), // Dodajte padding oko slike ako želite
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                child: generateTextField(
                  labelText: "Korisničko ime",
                  controller: _usernameController,
                  iconData: Icons.email,
                  focusNode: _usernameFocusNode,
                  validator: nameValidator,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                child: generateTextField(
                    labelText: "Šifra",
                    controller: _passwordController,
                    iconData: Icons.lock,
                    isPassword: true,
                    focusNode: _passwordFocusNode,
                    validator: passwordValidator),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                child: generateButton(
                  text: "Prijavite se na portal",
                  onPressed: _login,
                ),
              ),
              if (errorInfo.isNotEmpty) ...[
                const SizedBox(height: 6), // razmak između TextField i label
                Text(
                  errorInfo,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
