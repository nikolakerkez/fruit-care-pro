import 'package:flutter/material.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/exceptions/login_exception.dart';
import 'package:fruit_care_pro/services/notification_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:provider/provider.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/change_password_screen.dart';
import 'package:fruit_care_pro/user_notifier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Text controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // UI state
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final UserService _userService;

  // Email domain constant - should be in config file
  static const String _emailDomain = '@fruitcarepro.com';

@override
void initState() {
  super.initState();
  _userService = context.read<UserService>();
}

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates username input
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite korisničko ime';
    }
    // Add more validation rules if needed
    return null;
  }

  /// Validates password input
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite šifru';
    }
    if (value.length < 6) {
      return 'Šifra mora imati barem 6 karaktera';
    }
    return null;
  }

  /// Handles the login flow
  Future<void> _handleLogin() async {
    // Clear previous error
    setState(() => _errorMessage = null);

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final email = '$username$_emailDomain';

      // Attempt login
      final appUser = await _userService.login(email, password);

      if (!mounted) return;

      // Handle login result
      if (appUser == null) {
        _showError('Ne postoji korisnik. Pokušajte ponovo.');
        return;
      }

      if (!appUser.isActive) {
        _showError(
            'Vaš nalog nije više aktivan, kontaktirajte administratora.');
        return;
      }

      // Update user state
      Provider.of<UserNotifier>(context, listen: false).setUser(appUser);

      CurrentUserService.instance.setCurrentUser(appUser);

      // Navigate based on user status
      _navigateToNextScreen(appUser);
    } on LoginException catch (e) {
      // Handle known login errors with user-friendly messages
      if (!mounted) return;
      _showError(e.message);

      await ErrorLogger.logError(
        e,
        StackTrace.current,
        reason: 'Login failed - known error',
        screen: 'LoginScreen',
        additionalData: {'error_message': e.message},
      );
    } catch (e, stackTrace) {
      // Handle unexpected errors
      if (!mounted) return;
      _showError('Došlo je do neočekivane greške. Pokušajte ponovo.');

      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Login failed - unexpected error',
        screen: 'LoginScreen',
        fatal: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows error message
  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  /// Navigates to appropriate screen based on user type and status
void _navigateToNextScreen(AppUser user) {
  Widget nextScreen;

  if (user.isPasswordChangeNeeded) {
    nextScreen = ChangePasswordScreen();
  } else if (user.isAdmin) {
    nextScreen = const AdminMainScreen();
  } else {
    nextScreen = const UserMainScreen();
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => nextScreen),
  ).then((_) {
    // Navigator je spreman, obradi pending notifikaciju
    NotificationService.handlePendingNotification();
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Logo + title
                const SizedBox(height: 16),
                Image.asset('assets/images/app_icon5.png', width: 90, height: 90),
                const SizedBox(height: 16),
                const Text(
                  'Fruit Care Pro',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF388E3C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Prijavite se na vaš nalog',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 36),

                // Form card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        generateTextField(
                          labelText: "Korisničko ime",
                          controller: _usernameController,
                          iconData: Icons.person_outline,
                          validator: _validateUsername,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        generateTextField(
                          labelText: "Šifra",
                          controller: _passwordController,
                          iconData: Icons.lock_outline,
                          isPassword: _obscurePassword,
                          validator: _validatePassword,
                          enabled: !_isLoading,
                          sufixIconWidget: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B7280),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF388E3C),
                              )
                            : generateButton(
                                text: "Prijavite se",
                                onPressed: _handleLogin,
                              ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
