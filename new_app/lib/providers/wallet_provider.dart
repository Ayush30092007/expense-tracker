import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/wallet_model.dart';

class WalletProvider with ChangeNotifier {
  List<WalletModel> _wallets = [];
  WalletModel? _selectedWallet;
  bool _isLoading = false;
  String? _userId;

  StreamSubscription<List<WalletModel>>? _walletsSubscription;

  List<WalletModel> get wallets => _wallets;
  WalletModel? get selectedWallet => _selectedWallet;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _walletsSubscription?.cancel();
    super.dispose();
  }

  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    if (_userId == null) return;

    _walletsSubscription?.cancel();
    _walletsSubscription = FirebaseService.instance
        .getWalletsStream(_userId!)
        .listen((wallets) {
      _wallets = wallets;
      if (_selectedWallet != null) {
        _selectedWallet = _wallets.firstWhere(
          (w) => w.id == _selectedWallet!.id,
          orElse: () => _wallets.isNotEmpty ? _wallets.first : _selectedWallet!,
        );
      }
      notifyListeners();
    });
  }

  Future<void> loadWallets() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _wallets = await FirebaseService.instance.getWallets(_userId!);
      if (_selectedWallet != null) {
        _selectedWallet = _wallets.firstWhere(
          (w) => w.id == _selectedWallet!.id,
          orElse: () => _wallets.isNotEmpty ? _wallets.first : _selectedWallet!,
        );
      }
    } catch (e) {
      debugPrint('Error loading wallets: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectWallet(WalletModel? wallet) {
    _selectedWallet = wallet;
    notifyListeners();
  }

  Future<bool> addWallet(WalletModel wallet) async {
    try {
      await FirebaseService.instance.createWallet(wallet);
      return true;
    } catch (e) {
      debugPrint('Error adding wallet: $e');
      return false;
    }
  }

  Future<bool> updateWallet(WalletModel wallet) async {
    try {
      await FirebaseService.instance.updateWallet(wallet);
      return true;
    } catch (e) {
      debugPrint('Error updating wallet: $e');
      return false;
    }
  }

  Future<bool> deleteWallet(String id) async {
    try {
      await FirebaseService.instance.deleteWallet(id);
      if (_selectedWallet?.id == id) _selectedWallet = null;
      return true;
    } catch (e) {
      debugPrint('Error deleting wallet: $e');
      return false;
    }
  }

  double get totalBalance {
    return _wallets.fold(0.0, (sum, w) => sum + w.balance);
  }

  void clear() {
    _walletsSubscription?.cancel();
    _walletsSubscription = null;
    _wallets = [];
    _selectedWallet = null;
    _userId = null;
    notifyListeners();
  }
}
