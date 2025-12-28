import 'package:flutter/material.dart';
import 'package:fruit_care_pro/models/user.dart';

class UserNotifier extends ChangeNotifier {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  void setUser(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }
}
