import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fruit_care_pro/current_user_service.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/change_password_screen.dart';
import 'package:fruit_care_pro/screens/login_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/services/notification_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/user_notifier.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      _goToLogin();
      return;
    }

    try {
      final userService = context.read<UserService>();
      final appUser = await userService.getUserById(firebaseUser.uid);

      if (!mounted) return;

      if (appUser == null || !appUser.isActive) {
        _goToLogin();
        return;
      }

      Provider.of<UserNotifier>(context, listen: false).setUser(appUser);
      CurrentUserService.instance.setCurrentUser(appUser);

      await NotificationService.saveTokenAfterLogin();

      if (!mounted) return;
      _goToMain(appUser);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.handlePendingNotification();
      });
    } catch (e) {
      debugPrint('❌ SplashScreen auth check error: $e');
      if (mounted) _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToMain(AppUser user) {
    Widget next;
    if (user.isPasswordChangeNeeded) {
      next = ChangePasswordScreen();
    } else if (user.isAdmin) {
      next = const AdminMainScreen();
    } else {
      next = const UserMainScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF388E3C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/MIS.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 60,
            right: 60,
            bottom: 60,
            child: LinearProgressIndicator(
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}
