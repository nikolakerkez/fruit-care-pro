import 'package:bb_agro_portal/models/user.dart';

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

  AppUser? get currentUser => _currentUser;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
}
