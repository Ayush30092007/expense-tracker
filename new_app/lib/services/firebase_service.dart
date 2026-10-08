import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/savings_goal_model.dart';
import '../models/wallet_model.dart';
import '../models/recurring_expense_model.dart';

/// Firebase service that handles all Firestore operations with real-time synchronization
class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();

  FirebaseService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _expensesCollection => _firestore.collection('expenses');
  CollectionReference get _goalsCollection => _firestore.collection('savings_goals');
  CollectionReference get _walletsCollection => _firestore.collection('wallets');
  CollectionReference get _recurringCollection => _firestore.collection('recurring_expenses');

  // ═══════════════════════════════════════════════
  // ─── User Operations ───
  // ═══════════════════════════════════════════════

  Future<String> createUser(UserModel user) async {
    final docRef = await _usersCollection.add(user.toMap());
    return docRef.id;
  }

  Future<UserModel?> getUser(String username) async {
    final snapshot = await _usersCollection
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    return UserModel.fromMap({...data, 'id': snapshot.docs.first.id});
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _usersCollection.doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap({...data, 'id': doc.id});
  }

  Future<UserModel?> authenticateUser(String username, String password) async {
    final snapshot = await _usersCollection
        .where('username', isEqualTo: username)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data() as Map<String, dynamic>;
    return UserModel.fromMap({...data, 'id': snapshot.docs.first.id});
  }

  Future<void> updateUser(UserModel user) async {
    if (user.id == null) return;
    await _usersCollection.doc(user.id).update(user.toMap());
  }

  // Real-time user updates
  Stream<UserModel?> getUserStream(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      return UserModel.fromMap({...data, 'id': snapshot.id});
    });
  }

  // ═══════════════════════════════════════════════
  // ─── Expense Operations ───
  // ═══════════════════════════════════════════════

  Future<String> createExpense(ExpenseModel expense) async {
    final docRef = await _expensesCollection.add(expense.toMap());
    return docRef.id;
  }

  Future<List<ExpenseModel>> getExpenses(
    String userId, {
    bool showHidden = false,
  }) async {
    Query query = _expensesCollection.where('user_id', isEqualTo: userId);

    if (!showHidden) {
      query = query.where('is_hidden', isEqualTo: false);
    }

    final snapshot = await query.orderBy('date', descending: true).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return ExpenseModel.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  Future<List<ExpenseModel>> getExpensesByDateRange(
    String userId,
    DateTime start,
    DateTime end, {
    bool showHidden = false,
  }) async {
    Query query = _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String());

    if (!showHidden) {
      query = query.where('is_hidden', isEqualTo: false);
    }

    final snapshot = await query.orderBy('date', descending: true).get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return ExpenseModel.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  Future<List<ExpenseModel>> getExpensesByMonth(
    String userId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return getExpensesByDateRange(userId, start, end);
  }

  Future<List<ExpenseModel>> getTodayExpenses(String userId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getExpensesByDateRange(userId, start, end);
  }

  Future<List<ExpenseModel>> getLast7DaysExpenses(String userId) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getExpensesByDateRange(userId, start, end);
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    if (expense.id == null) return;
    await _expensesCollection.doc(expense.id).update(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    await _expensesCollection.doc(id).delete();
  }

  Future<double> getMonthlyTotal(
    String userId,
    int year,
    int month, {
    String type = 'expense',
  }) async {
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    final snapshot = await _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('is_hidden', isEqualTo: false)
        .where('type', isEqualTo: type)
        .get();

    double total = 0.0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return total;
  }

  Future<double> getMonthlyIncome(String userId, int year, int month) async {
    return getMonthlyTotal(userId, year, month, type: 'income');
  }

  Future<double> getMonthlyExpense(String userId, int year, int month) async {
    return getMonthlyTotal(userId, year, month, type: 'expense');
  }

  Future<Map<String, double>> getCategoryTotals(
    String userId,
    int year,
    int month, {
    String? type,
  }) async {
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    Query query = _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('is_hidden', isEqualTo: false);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final snapshot = await query.get();

    final map = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] as String;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      map[category] = (map[category] ?? 0.0) + amount;
    }

    return map;
  }

  Future<List<Map<String, dynamic>>> getDailyTotals(
    String userId,
    int days,
  ) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );

    final snapshot = await _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .where('is_hidden', isEqualTo: false)
        .where('type', isEqualTo: 'expense')
        .get();

    final dailyMap = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = DateTime.parse(data['date'] as String);
      final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + amount;
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in dailyMap.entries) {
      result.add({'day': entry.key, 'total': entry.value});
    }
    result.sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));

    return result;
  }

  Future<Map<String, double>> getCategoryTotalsByDateRange(
    String userId,
    DateTime start,
    DateTime end, {
    String? type,
  }) async {
    Query query = _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .where('is_hidden', isEqualTo: false);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final snapshot = await query.get();

    final map = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] as String;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      map[category] = (map[category] ?? 0.0) + amount;
    }

    return map;
  }

  Future<double> getTotalByDateRange(
    String userId,
    DateTime start,
    DateTime end, {
    String type = 'expense',
  }) async {
    final snapshot = await _expensesCollection
        .where('user_id', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThanOrEqualTo: end.toIso8601String())
        .where('is_hidden', isEqualTo: false)
        .where('type', isEqualTo: type)
        .get();

    double total = 0.0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return total;
  }

  Future<List<Map<String, dynamic>>> getAllExpensesRaw(String userId) async {
    final snapshot = await _expensesCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();
  }

  // Real-time expense updates
  Stream<List<ExpenseModel>> getExpensesStream(
    String userId, {
    bool showHidden = false,
  }) {
    Query query = _expensesCollection.where('user_id', isEqualTo: userId);

    if (!showHidden) {
      query = query.where('is_hidden', isEqualTo: false);
    }

    return query.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ExpenseModel.fromMap({...data, 'id': doc.id});
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════
  // ─── Savings Goals Operations ───
  // ═══════════════════════════════════════════════

  Future<String> createSavingsGoal(SavingsGoalModel goal) async {
    final docRef = await _goalsCollection.add(goal.toMap());
    return docRef.id;
  }

  Future<List<SavingsGoalModel>> getSavingsGoals(String userId) async {
    final snapshot = await _goalsCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return SavingsGoalModel.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    if (goal.id == null) return;
    await _goalsCollection.doc(goal.id).update(goal.toMap());
  }

  Future<void> deleteSavingsGoal(String id) async {
    await _goalsCollection.doc(id).delete();
  }

  // Real-time goals stream
  Stream<List<SavingsGoalModel>> getSavingsGoalsStream(String userId) {
    return _goalsCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SavingsGoalModel.fromMap({...data, 'id': doc.id});
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════
  // ─── Wallet Operations ───
  // ═══════════════════════════════════════════════

  Future<String> createWallet(WalletModel wallet) async {
    final docRef = await _walletsCollection.add(wallet.toMap());
    return docRef.id;
  }

  Future<List<WalletModel>> getWallets(String userId) async {
    final snapshot = await _walletsCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return WalletModel.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  Future<void> updateWallet(WalletModel wallet) async {
    if (wallet.id == null) return;
    await _walletsCollection.doc(wallet.id).update(wallet.toMap());
  }

  Future<void> deleteWallet(String id) async {
    await _walletsCollection.doc(id).delete();
  }

  // Real-time wallets stream
  Stream<List<WalletModel>> getWalletsStream(String userId) {
    return _walletsCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return WalletModel.fromMap({...data, 'id': doc.id});
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════
  // ─── Recurring Expenses Operations ───
  // ═══════════════════════════════════════════════

  Future<String> createRecurringExpense(RecurringExpenseModel recurring) async {
    final docRef = await _recurringCollection.add(recurring.toMap());
    return docRef.id;
  }

  Future<List<RecurringExpenseModel>> getRecurringExpenses(String userId) async {
    final snapshot = await _recurringCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return RecurringExpenseModel.fromMap({...data, 'id': doc.id});
    }).toList();
  }

  Future<void> updateRecurringExpense(RecurringExpenseModel recurring) async {
    if (recurring.id == null) return;
    await _recurringCollection.doc(recurring.id).update(recurring.toMap());
  }

  Future<void> deleteRecurringExpense(String id) async {
    await _recurringCollection.doc(id).delete();
  }

  // Real-time recurring expenses stream
  Stream<List<RecurringExpenseModel>> getRecurringExpensesStream(String userId) {
    return _recurringCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RecurringExpenseModel.fromMap({...data, 'id': doc.id});
      }).toList();
    });
  }
}
