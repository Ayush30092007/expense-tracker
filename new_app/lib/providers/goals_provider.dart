import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/savings_goal_model.dart';

class GoalsProvider with ChangeNotifier {
  List<SavingsGoalModel> _goals = [];
  bool _isLoading = false;
  String? _userId;

  StreamSubscription<List<SavingsGoalModel>>? _goalsSubscription;

  List<SavingsGoalModel> get goals => _goals;
  List<SavingsGoalModel> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<SavingsGoalModel> get completedGoals => _goals.where((g) => g.isCompleted).toList();
  bool get isLoading => _isLoading;

  int get totalBadges {
    int count = 0;
    for (final g in _goals) {
      if (g.isCompleted) {
        count += 4; // All badges
      } else if (g.progress >= 0.75) {
        count += 3;
      } else if (g.progress >= 0.50) {
        count += 2;
      } else if (g.progress >= 0.25) {
        count += 1;
      }
    }
    return count;
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    super.dispose();
  }

  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    if (_userId == null) return;

    _goalsSubscription?.cancel();
    _goalsSubscription = FirebaseService.instance
        .getSavingsGoalsStream(_userId!)
        .listen((goals) {
      _goals = goals;
      notifyListeners();
    });
  }

  Future<void> loadGoals() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _goals = await FirebaseService.instance.getSavingsGoals(_userId!);
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addGoal(SavingsGoalModel goal) async {
    try {
      await FirebaseService.instance.createSavingsGoal(goal);
      return true;
    } catch (e) {
      debugPrint('Error adding goal: $e');
      return false;
    }
  }

  Future<bool> updateGoal(SavingsGoalModel goal) async {
    try {
      await FirebaseService.instance.updateSavingsGoal(goal);
      return true;
    } catch (e) {
      debugPrint('Error updating goal: $e');
      return false;
    }
  }

  Future<bool> addSavings(String goalId, double amount) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) return false;
    final goal = _goals[idx];
    final updated = goal.copyWith(savedAmount: goal.savedAmount + amount);
    return await updateGoal(updated);
  }

  Future<bool> deleteGoal(String id) async {
    try {
      await FirebaseService.instance.deleteSavingsGoal(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      return false;
    }
  }

  void clear() {
    _goalsSubscription?.cancel();
    _goalsSubscription = null;
    _goals = [];
    _userId = null;
    notifyListeners();
  }
}
