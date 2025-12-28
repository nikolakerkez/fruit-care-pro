import 'package:fruit_care_pro/models/change_password_result.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/models/user.dart';

class ChangePasswordScreen extends StatefulWidget {
  final AppUser? appUser;

  const ChangePasswordScreen({super.key, required this.appUser});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  AppUser? appUser;
  String errorInfo = "";
  //---Password text controllers---
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  //---Password text controllers---

  //---Password focus nodes---
  final FocusNode _oldPasswordFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  //---Password focus nodes---

  //Service for changing passowrd
  final UserService _userService = UserService();

  //Form key for validation
  final _formKey = GlobalKey<FormState>();

  //Loading flag
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    appUser = widget.appUser;
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String? oldPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite šifru';
    }
    if (value.length < 6) {
      return 'Šifra mora imati barem 6 karaktera';
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

  String? confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo ponovite šifru';
    }
    if (value != _passwordController.text) {
      return 'Šifre se ne poklapaju';
    }
    return null;
  }

  Future<void> changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    String oldPassword = _oldPasswordController.text;
    String newPassword = _passwordController.text;

    ChangePasswordResult result = await _userService.changePassword(
        appUser?.id ?? '', oldPassword, newPassword);

    setState(() {
      _isLoading = false;
    });
    if (!mounted) return;

    if (result.isWrongPasswordProvided) {
      errorInfo = "Stara šifra koju ste uneli nije ispravna.";
      return;
    }

    if (result.isFailed) {
      errorInfo = "Došlo je do greške. Šifra nije promenjena.";
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Šifra uspešno promenjena.")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 4),
        child: Container(
          color: Colors.green[800],
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(
                  'Izmena šifre',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 4,
                color: Colors.brown[500],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [
            Container(
              color: Colors.transparent,
              padding: EdgeInsets.all(30),
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
                labelText: "Stara šifra",
                controller: _oldPasswordController,
                iconData: Icons.lock,
                isPassword: true,
                focusNode: _oldPasswordFocusNode,
                validator: oldPasswordValidator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: generateTextField(
                labelText: "Nova šifra",
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
                labelText: "Ponovi šifru",
                controller: _confirmPasswordController,
                iconData: Icons.lock_outline,
                isPassword: true,
                focusNode: _confirmPasswordFocusNode,
                validator: confirmPasswordValidator,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              child: generateButton(
                text: _isLoading ? "Sačekajte..." : "Potvrdi",
                onPressed: /*_isLoading ? null :*/ changePassword,
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
            ],
          ]),
        ),
      ),
    );
  }
}
