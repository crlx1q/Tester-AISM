import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class ProfileNotifier extends ChangeNotifier {
  static final ProfileNotifier _instance = ProfileNotifier._internal();
  factory ProfileNotifier() => _instance;
  ProfileNotifier._internal();

  User? _user;
  User? get user => _user;

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
