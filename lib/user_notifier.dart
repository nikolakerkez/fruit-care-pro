import 'package:flutter/material.dart';
import 'package:bb_agro_portal/models/user.dart';

class UserNotifier extends ChangeNotifier {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  void setUser(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }
}
