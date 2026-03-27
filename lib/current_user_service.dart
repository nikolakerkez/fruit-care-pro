import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fruit_care_pro/models/user.dart';

class CurrentUserService {
  static final CurrentUserService _instance = CurrentUserService._internal();
  AppUser? _currentUser;
  StreamSubscription? _firestoreSubscription;

  final StreamController<AppUser> _userUpdatesController =
      StreamController<AppUser>.broadcast();

  /// Emits once when the current user is deactivated remotely.
  final StreamController<void> _forceLogoutController =
      StreamController<void>.broadcast();

  CurrentUserService._internal();

  static CurrentUserService get instance => _instance;

  /// Stream that emits whenever the current user's data changes in Firestore.
  Stream<AppUser> get userUpdates => _userUpdatesController.stream;

  /// Stream that emits when the user's account is deactivated by an admin.
  Stream<void> get forceLogoutStream => _forceLogoutController.stream;

  void setCurrentUser(AppUser user) {
    _currentUser = user;
    _startListening(user.id);
  }

  void _startListening(String userId) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final updated = AppUser.fromFirestore(
          doc.data()!,
          doc.id,
          _currentUser?.fruitTypes ?? [],
        );

        // If the user was just deactivated, trigger force logout.
        if ((_currentUser?.isActive ?? true) && !updated.isActive) {
          _forceLogoutController.add(null);
        }

        _currentUser = updated;
        _userUpdatesController.add(updated);
      }
    });
  }

  void clearUser() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _currentUser = null;
  }

  AppUser? get currentUser => _currentUser;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
}
