import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';

class ExpenseProvider with ChangeNotifier {
  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> _todayExpenses = [];
  List<ExpenseModel> _monthlyExpenses = [];
  List<ExpenseModel> _last7DaysExpenses = [];
  List<RecurringExpenseModel> _recurringExpenses = [];
  Map<String, double> _categoryTotals = {};
  Map<String, double> _incomeCategoryTotals = {};
  List<Map<String, dynamic>> _dailyTotals = [];
  double _monthlyTotal = 0;
  double _monthlyIncomeTotal = 0;
  double _previousMonthTotal = 0;
  double _todayTotal = 0;
  bool _isLoading = false;
  String? _userId;

  StreamSubscription<List<ExpenseModel>>? _expenseSubscription;
  StreamSubscription<List<RecurringExpenseModel>>? _recurringSubscription;

  List<ExpenseModel> get expenses => _expenses;
  List<ExpenseModel> get todayExpenses => _todayExpenses;
  List<ExpenseModel> get monthlyExpenses => _monthlyExpenses;
  List<ExpenseModel> get last7DaysExpenses => _last7DaysExpenses;
  List<RecurringExpenseModel> get recurringExpenses => _recurringExpenses;
  Map<String, double> get categoryTotals => _categoryTotals;
  Map<String, double> get incomeCategoryTotals => _incomeCategoryTotals;
  List<Map<String, dynamic>> get dailyTotals => _dailyTotals;
  double get monthlyTotal => _monthlyTotal;
  double get monthlyIncomeTotal => _monthlyIncomeTotal;
  double get previousMonthTotal => _previousMonthTotal;
  double get todayTotal => _todayTotal;
  bool get isLoading => _isLoading;

  // Net balance for the month (income - expense)
  double get monthlyNetBalance => _monthlyIncomeTotal - _monthlyTotal;

  // Only expense items from today
  List<ExpenseModel> get todayExpenseOnly =>
      _todayExpenses.where((e) => e.isExpense).toList();
  List<ExpenseModel> get todayIncomeOnly =>
      _todayExpenses.where((e) => e.isIncome).toList();

  // Monthly filtered lists
  List<ExpenseModel> get monthlyExpenseOnly =>
      _monthlyExpenses.where((e) => e.isExpense).toList();
  List<ExpenseModel> get monthlyIncomeOnly =>
      _monthlyExpenses.where((e) => e.isIncome).toList();

  double get monthOverMonthChange {
    if (_previousMonthTotal == 0) return 0;
    return ((_monthlyTotal - _previousMonthTotal) / _previousMonthTotal * 100);
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    _recurringSubscription?.cancel();
    super.dispose();
  }

  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    if (_userId == null) return;

    _expenseSubscription?.cancel();
    _expenseSubscription = FirebaseService.instance
        .getExpensesStream(_userId!)
        .listen(
          (expenses) {
            _expenses = expenses;
            _recalculateAggregates();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Error listening to expenses: $error');
          },
        );

    _recurringSubscription?.cancel();
    _recurringSubscription = FirebaseService.instance
        .getRecurringExpensesStream(_userId!)
        .listen((recurring) {
          _recurringExpenses = recurring;
          notifyListeners();
        });
  }

  void _recalculateAggregates() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final last7Start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    _todayExpenses = _expenses
        .where(
          (e) =>
              e.date.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(todayEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    _monthlyExpenses = _expenses
        .where(
          (e) =>
              e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    _last7DaysExpenses = _expenses
        .where(
          (e) =>
              e.date.isAfter(last7Start.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(todayEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    _monthlyTotal = _monthlyExpenses
        .where((e) => e.isExpense)
        .fold(0.0, (sum, e) => sum + e.amount);

    _monthlyIncomeTotal = _monthlyExpenses
        .where((e) => e.isIncome)
        .fold(0.0, (sum, e) => sum + e.amount);

    final prevMonthExpenses = _expenses
        .where(
          (e) =>
              e.date.isAfter(
                prevMonthStart.subtract(const Duration(seconds: 1)),
              ) &&
              e.date.isBefore(prevMonthEnd.add(const Duration(seconds: 1))),
        )
        .toList();

    _previousMonthTotal = prevMonthExpenses
        .where((e) => e.isExpense)
        .fold(0.0, (sum, e) => sum + e.amount);

    _categoryTotals = {};
    for (final e in _monthlyExpenses.where((e) => e.isExpense)) {
      _categoryTotals[e.category] =
          (_categoryTotals[e.category] ?? 0.0) + e.amount;
    }

    _incomeCategoryTotals = {};
    for (final e in _monthlyExpenses.where((e) => e.isIncome)) {
      _incomeCategoryTotals[e.category] =
          (_incomeCategoryTotals[e.category] ?? 0.0) + e.amount;
    }

    // Daily totals for last 7 days
    final dailyMap = <String, double>{};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final dayKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dailyMap[dayKey] = 0.0;
    }

    for (final e in _last7DaysExpenses.where((e) => e.isExpense)) {
      final dayKey =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      if (dailyMap.containsKey(dayKey)) {
        dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + e.amount;
      }
    }

    _dailyTotals = dailyMap.entries
        .map((entry) => {'day': entry.key, 'total': entry.value})
        .toList();

    _todayTotal = _todayExpenses
        .where((e) => e.isExpense)
        .fold(0.0, (sum, e) => sum + e.amount);

    _recalculateRangeAggregates();
    notifyListeners();
  }

  Future<void> loadExpenses() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = await FirebaseService.instance.getExpenses(_userId!);
      _recalculateAggregates();

      _recurringExpenses = await FirebaseService.instance.getRecurringExpenses(
        _userId!,
      );
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMonthExpenses(int year, int month) async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    final monthStart = DateTime(year, month, 1);
    final nextMonthStart = DateTime(year, month + 1, 1);
    _monthlyExpenses = _expenses
        .where(
          (expense) =>
              !expense.date.isBefore(monthStart) &&
              expense.date.isBefore(nextMonthStart),
        )
        .toList();
    _monthlyTotal = _monthlyExpenses
        .where((expense) => expense.isExpense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    _monthlyIncomeTotal = _monthlyExpenses
        .where((expense) => expense.isIncome)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    _categoryTotals = _totalsByCategory(_monthlyExpenses, isIncome: false);
    _incomeCategoryTotals = _totalsByCategory(_monthlyExpenses, isIncome: true);

    _isLoading = false;
    notifyListeners();
  }

  // ─── Date Range Support ───
  List<ExpenseModel> _rangeExpenses = [];
  Map<String, double> _rangeCategoryTotals = {};
  Map<String, double> _rangeIncomeCategoryTotals = {};
  double _rangeExpenseTotal = 0;
  double _rangeIncomeTotal = 0;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  List<ExpenseModel> get rangeExpenses => _rangeExpenses;
  Map<String, double> get rangeCategoryTotals => _rangeCategoryTotals;
  Map<String, double> get rangeIncomeCategoryTotals =>
      _rangeIncomeCategoryTotals;
  double get rangeExpenseTotal => _rangeExpenseTotal;
  double get rangeIncomeTotal => _rangeIncomeTotal;
  List<ExpenseModel> get rangeExpenseOnly =>
      _rangeExpenses.where((e) => e.isExpense).toList();
  List<ExpenseModel> get rangeIncomeOnly =>
      _rangeExpenses.where((e) => e.isIncome).toList();

  Future<void> loadDateRangeExpenses(DateTime start, DateTime end) async {
    _rangeStart = DateTime(start.year, start.month, start.day);
    _rangeEnd = DateTime(end.year, end.month, end.day);
    _recalculateRangeAggregates();
    notifyListeners();
  }

  void _recalculateRangeAggregates() {
    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) return;

    final endExclusive = DateTime(end.year, end.month, end.day + 1);
    _rangeExpenses = _expenses
        .where(
          (expense) =>
              !expense.date.isBefore(start) &&
              expense.date.isBefore(endExclusive),
        )
        .toList();
    _rangeExpenseTotal = _rangeExpenses
        .where((expense) => expense.isExpense)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    _rangeIncomeTotal = _rangeExpenses
        .where((expense) => expense.isIncome)
        .fold(0.0, (sum, expense) => sum + expense.amount);
    _rangeCategoryTotals = _totalsByCategory(_rangeExpenses, isIncome: false);
    _rangeIncomeCategoryTotals = _totalsByCategory(
      _rangeExpenses,
      isIncome: true,
    );
  }

  Map<String, double> _totalsByCategory(
    List<ExpenseModel> expenses, {
    required bool isIncome,
  }) {
    final totals = <String, double>{};
    for (final expense in expenses.where(
      (expense) => expense.isIncome == isIncome,
    )) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
    return totals;
  }

  Future<bool> addExpense(ExpenseModel expense) async {
    try {
      await FirebaseService.instance.createExpense(expense);
      return true;
    } catch (e) {
      debugPrint('Error adding expense: $e');
      return false;
    }
  }

  Future<bool> updateExpense(ExpenseModel expense) async {
    try {
      await FirebaseService.instance.updateExpense(expense);
      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await FirebaseService.instance.deleteExpense(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // ─── Recurring Expenses ───

  Future<bool> addRecurringExpense(RecurringExpenseModel recurring) async {
    try {
      await FirebaseService.instance.createRecurringExpense(recurring);
      return true;
    } catch (e) {
      debugPrint('Error adding recurring: $e');
      return false;
    }
  }

  Future<bool> deleteRecurringExpense(String id) async {
    try {
      await FirebaseService.instance.deleteRecurringExpense(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recurring: $e');
      return false;
    }
  }

  Future<bool> toggleRecurring(RecurringExpenseModel recurring) async {
    try {
      final updated = recurring.copyWith(isActive: !recurring.isActive);
      await FirebaseService.instance.updateRecurringExpense(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Analytics helpers ───

  List<double> get sparklineData {
    final now = DateTime.now();
    final data = <double>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final dayStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final match = _dailyTotals.where((d) => (d['day'] as String?) == dayStr);
      if (match.isNotEmpty) {
        data.add((match.first['total'] as num?)?.toDouble() ?? 0);
      } else {
        data.add(0);
      }
    }
    return data;
  }

  // Simple linear regression for trend
  Map<String, dynamic> get spendingTrend {
    final data = sparklineData;
    if (data.every((d) => d == 0)) return {'slope': 0.0, 'direction': 'flat'};

    final n = data.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += data[i];
      sumXY += i * data[i];
      sumX2 += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    String direction;
    if (slope > 5) {
      direction = 'increasing';
    } else if (slope < -5) {
      direction = 'decreasing';
    } else {
      direction = 'stable';
    }
    return {'slope': slope, 'direction': direction};
  }

  void clear() {
    _expenseSubscription?.cancel();
    _expenseSubscription = null;
    _recurringSubscription?.cancel();
    _recurringSubscription = null;
    _expenses = [];
    _todayExpenses = [];
    _monthlyExpenses = [];
    _last7DaysExpenses = [];
    _recurringExpenses = [];
    _categoryTotals = {};
    _incomeCategoryTotals = {};
    _dailyTotals = [];
    _monthlyTotal = 0;
    _monthlyIncomeTotal = 0;
    _previousMonthTotal = 0;
    _todayTotal = 0;
    _userId = null;
    notifyListeners();
  }
}
