class RecurringExpenseModel {
  final String? id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final String? walletId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastTriggered;
  final bool isActive;
  final DateTime createdAt;

  RecurringExpenseModel({
    this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    this.walletId,
    required this.startDate,
    this.endDate,
    this.lastTriggered,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency,
      'wallet_id': walletId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'last_triggered': lastTriggered?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory RecurringExpenseModel.fromMap(Map<String, dynamic> map) {
    bool parseIsActive(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return true;
    }

    return RecurringExpenseModel(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: (map['category'] as String?) ?? 'Other',
      frequency: (map['frequency'] as String?) ?? 'monthly',
      walletId: map['wallet_id']?.toString(),
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      lastTriggered: map['last_triggered'] != null
          ? DateTime.parse(map['last_triggered'] as String)
          : null,
      isActive: parseIsActive(map['is_active']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  RecurringExpenseModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? category,
    String? frequency,
    String? walletId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastTriggered,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RecurringExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      walletId: walletId ?? this.walletId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  DateTime get nextDueDate {
    final base = lastTriggered ?? startDate;
    switch (frequency) {
      case 'daily':
        return base.add(const Duration(days: 1));
      case 'weekly':
        return base.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(base.year, base.month + 1, base.day);
      case 'yearly':
        return DateTime(base.year + 1, base.month, base.day);
      default:
        return base.add(const Duration(days: 30));
    }
  }

  bool get isDue => DateTime.now().isAfter(nextDueDate);

  static const frequencies = [
    {'key': 'daily', 'label': 'Daily', 'icon': '📅'},
    {'key': 'weekly', 'label': 'Weekly', 'icon': '📆'},
    {'key': 'monthly', 'label': 'Monthly', 'icon': '🗓️'},
    {'key': 'yearly', 'label': 'Yearly', 'icon': '🎯'},
  ];
}
