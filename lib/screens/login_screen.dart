import 'package:bb_agro_portal/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/screens/create_account_screen.dart';
import 'package:bb_agro_portal/shared_ui_components.dart';  // Popravio sam grešku u importu (dva tačka)
import 'package:bb_agro_portal/models/user.dart';
import 'package:bb_agro_portal/services/user_service.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';
import 'package:bb_agro_portal/screens/admin_main_screen.dart';
import 'package:provider/provider.dart';
import 'package:bb_agro_portal/user_notifier.dart';
import 'package:bb_agro_portal/current_user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>(); // Dodajemo FormKey za validaciju
  bool _isLoading = false;
  String errorInfo = "";
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(() {

      if (_usernameFocusNode.hasFocus)
      {
      setState(() {
                // Resetuj validator na null kada je u fokusu
      
              });
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus)
      {
        setState(() {
          // Resetuj validator na null kada je u fokusu
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
      return 'Molimo unesite korisnincko ime';
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
    if (_formKey.currentState?.validate() ?? false) {
      // Ako su podaci validni, pozivamo login
      setState(() {
        _isLoading = true;
      });

      String username = _usernameController.text;
      String password = _passwordController.text;

      String email = username + "@agrobb.com";
      // Pozivanje AuthService za login
      AppUser? appUser = await _userService.login(email, password);

      setState(() {
        _isLoading = false;
      });

      Provider.of<UserNotifier>(context, listen: false).setUser(
        appUser!
      );

      CurrentUserService.instance.setCurrentUser(appUser);

      if (appUser != null) {
        if (!appUser.isActive)
        {
          errorInfo = "Vas nalog nije vise aktivan, kontaktirajte administratora.";
        }
        else if (appUser.isPasswordChangeNeeded)
        {
          // Ako je korisnik običan korisnik, preusmeri na user ekran
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChangePasswordScreen(appUser: appUser)),
          );
        }
        else if (appUser.isAdmin) {
          // Ako je korisnik admin, preusmeri na admin ekran
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminMainScreen(adminUser: appUser)),
          );
        } 
        else{
          // Ako je korisnik običan korisnik, preusmeri na user ekran
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserMainScreen(appUser: appUser)),
          );
        }
      } else {
        // Ako je došlo do greške prilikom logovanja
        // _showErrorDialog('Greška pri prijavi. Proverite vaše podatke.');
      }
    }
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
                color: Colors.orangeAccent[400],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,  // Povezivanje Form sa ključem
          child: Column(
            children: [
              Container(
                color: Colors.transparent, // Postavite pozadinsku boju na belu
                padding: EdgeInsets.all(30), // Dodajte padding oko slike ako želite
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                child: generateTextField(
                  labelText: "Korisnicko ime",
                  controller: _usernameController,
                  iconData: Icons.email,
                  focusNode: _usernameFocusNode,
                  validator: nameValidator,
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
                  validator: passwordValidator
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                child: generateButton(
                  text: "Prijavite se na portal",
                  onPressed: _login,
                ),
              ),
              if (errorInfo != null && errorInfo.isNotEmpty) ...[
                const SizedBox(height: 6), // razmak između TextField i label
                Text(
                  errorInfo,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                )]
              
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              //   child: GestureDetector(
              //     onTap: () => Navigator.of(context).push(
              //       MaterialPageRoute(builder: (_) => CreateAccountScreen()),
              //     ),
              //     child: Text(
              //       "Napravite novi nalog",
              //       style: TextStyle(
              //         color: Colors.green,
              //         fontSize: 15,
              //         fontWeight: FontWeight.bold,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
