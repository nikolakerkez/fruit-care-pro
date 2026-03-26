import 'package:flutter/material.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/exceptions/password_change_exception.dart';
import 'package:fruit_care_pro/exceptions/wrong_password_exception.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Text controllers
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  late final UserService _userService;

  // UI state
  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  late final AppUser _appUser;

  @override
  void initState() {
    super.initState();

    _appUser = CurrentUserService.instance.currentUser!;

    _userService = context.read<UserService>();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validates old password input
  String? _validateOldPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite staru šifru';
    }
    if (value.length < 6) {
      return 'Šifra mora imati barem 6 karaktera';
    }
    return null;
  }

  /// Validates new password input
  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo unesite novu šifru';
    }
    if (value.length < 6) {
      return 'Šifra mora imati barem 6 karaktera';
    }

    // Check if new password is same as old
    if (value == _oldPasswordController.text) {
      return 'Nova šifra mora biti različita od stare';
    }

    // Optional: Add password strength validation
    // if (!_hasUpperCase(value) || !_hasLowerCase(value) || !_hasDigit(value)) {
    //   return 'Šifra mora sadržati velika i mala slova, i brojeve';
    // }

    return null;
  }

  /// Validates confirm password input
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Molimo ponovite šifru';
    }
    if (value != _newPasswordController.text) {
      return 'Šifre se ne poklapaju';
    }
    return null;
  }

  /// Handles password change
  Future<void> _handleChangePassword() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _userService.changePassword(
        _appUser.id,
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) return;

      // Success
      _showSuccessAndNavigateToLogin();
    } on WrongPasswordException catch (e) {
      // Handle wrong password specifically
      if (!mounted) return;
      _showError(e.message);
    } on PasswordChangeException catch (e) {
      // Handle other password change errors
      if (!mounted) return;
      _showError(e.message);
    } catch (e, stackTrace) {
      // Handle unexpected errors
      if (!mounted) return;

      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Password change failed in UI',
        screen: 'ChangePasswordScreen',
      );

      _showError('Došlo je do neočekivane greške');
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

  /// Shows success message and navigates login
  void _showSuccessAndNavigateToLogin() {
    // Navigate to login and remove all previous routes
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false, // Remove all previous routes
    );

    // Show success message on login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Šifra uspešno promenjena. Prijavite se ponovo.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izmena šifre'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      generateTextField(
                        labelText: "Stara šifra",
                        controller: _oldPasswordController,
                        iconData: Icons.lock_outline,
                        isPassword: _obscureOldPassword,
                        validator: _validateOldPassword,
                        enabled: !_isLoading,
                        sufixIconWidget: IconButton(
                          icon: Icon(
                            _obscureOldPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureOldPassword = !_obscureOldPassword),
                        ),
                      ),
                      const SizedBox(height: 16),
                      generateTextField(
                        labelText: "Nova šifra",
                        controller: _newPasswordController,
                        iconData: Icons.lock_outline,
                        isPassword: _obscureNewPassword,
                        validator: _validateNewPassword,
                        enabled: !_isLoading,
                        sufixIconWidget: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                      const SizedBox(height: 16),
                      generateTextField(
                        labelText: "Ponovi novu šifru",
                        controller: _confirmPasswordController,
                        iconData: Icons.lock_outline,
                        isPassword: _obscureConfirmPassword,
                        validator: _validateConfirmPassword,
                        enabled: !_isLoading,
                        sufixIconWidget: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator(
                              color: Color(0xFF388E3C))
                          : generateButton(
                              text: "Potvrdi izmenu",
                              icon: Icons.check_rounded,
                              onPressed: _handleChangePassword,
                            ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Šifra mora imati najmanje 6 karaktera',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
