class ExpenseModel {
  final String? id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final String type; // 'expense' or 'income'
  final String? note;
  final DateTime date;
  final String? walletId;
  final String? receiptPath;
  final bool isHidden;
  final String? recurringId;
  final String? splitGroupId;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    this.type = 'expense',
    this.note,
    required this.date,
    this.walletId,
    this.receiptPath,
    this.isHidden = false,
    this.recurringId,
    this.splitGroupId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'type': type,
      'note': note,
      'date': date.toIso8601String(),
      'wallet_id': walletId,
      'receipt_path': receiptPath,
      'is_hidden': isHidden,
      'recurring_id': recurringId,
      'split_group_id': splitGroupId,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    bool parseIsHidden(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return false;
    }

    return ExpenseModel(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: (map['category'] as String?) ?? 'Other',
      type: (map['type'] as String?) ?? 'expense',
      note: map['note'] as String?,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      walletId: map['wallet_id']?.toString(),
      receiptPath: map['receipt_path'] as String?,
      isHidden: parseIsHidden(map['is_hidden']),
      recurringId: map['recurring_id']?.toString(),
      splitGroupId: map['split_group_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? category,
    String? type,
    String? note,
    DateTime? date,
    String? walletId,
    String? receiptPath,
    bool? isHidden,
    String? recurringId,
    String? splitGroupId,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
      walletId: walletId ?? this.walletId,
      receiptPath: receiptPath ?? this.receiptPath,
      isHidden: isHidden ?? this.isHidden,
      recurringId: recurringId ?? this.recurringId,
      splitGroupId: splitGroupId ?? this.splitGroupId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
