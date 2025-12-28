import 'package:fruit_care_pro/models/user.dart';

class CurrentUserService {
  static final CurrentUserService _instance = CurrentUserService._internal();
  AppUser? _currentUser;

  // privatni konstruktor
  CurrentUserService._internal();

  // globalni getter
  static CurrentUserService get instance => _instance;

  // setuj trenutnog korisnika
  void setCurrentUser(AppUser user) {
    _currentUser = user;
  }

   void clearUser() {
    _currentUser = null;
    // Ako imaš SharedPreferences ili nešto drugo, očisti i to
  }
  AppUser? get currentUser => _currentUser;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
}
