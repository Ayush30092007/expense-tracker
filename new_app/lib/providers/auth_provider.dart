import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<UserModel?>? _userSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToUser(String userId) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseService.instance.getUserStream(userId).listen((user) {
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    });
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('logged_in_user_id');
    if (userId != null) {
      final user = await FirebaseService.instance.getUserById(userId);
      if (user != null) {
        _currentUser = user;
        _listenToUser(userId);
        notifyListeners();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await FirebaseService.instance.authenticateUser(
        username.trim(),
        password,
      );
      if (user != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_in_user_id', user.id!);
        _listenToUser(user.id!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid username or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'An error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password, String displayName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existing = await FirebaseService.instance.getUser(username.trim());
      if (existing != null) {
        _error = 'Username already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = UserModel(
        username: username.trim(),
        password: password,
        displayName: displayName.trim(),
      );
      final id = await FirebaseService.instance.createUser(user);
      _currentUser = user.copyWith(id: id);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_user_id', id);

      _listenToUser(id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateCurrency(String currency) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(currency: currency);
    _currentUser = updated;
    await FirebaseService.instance.updateUser(updated);
    notifyListeners();
  }

  Future<void> updateBudget(double budget) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(monthlyBudget: budget);
    _currentUser = updated;
    await FirebaseService.instance.updateUser(updated);
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(displayName: name);
    _currentUser = updated;
    await FirebaseService.instance.updateUser(updated);
    notifyListeners();
  }

  Future<void> updateAvatar(String emoji) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(avatarEmoji: emoji);
    _currentUser = updated;
    await FirebaseService.instance.updateUser(updated);
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String? path) async {
    if (_currentUser == null) return;
    final updated = UserModel(
      id: _currentUser!.id,
      username: _currentUser!.username,
      password: _currentUser!.password,
      displayName: _currentUser!.displayName,
      currency: _currentUser!.currency,
      monthlyBudget: _currentUser!.monthlyBudget,
      avatarEmoji: _currentUser!.avatarEmoji,
      profilePhotoPath: path,
      pin: _currentUser!.pin,
      createdAt: _currentUser!.createdAt,
    );
    _currentUser = updated;
    await FirebaseService.instance.updateUser(updated);
    notifyListeners();
  }

  Future<void> logout() async {
    _userSubscription?.cancel();
    _userSubscription = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
