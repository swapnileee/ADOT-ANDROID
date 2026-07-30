class ExpenseModel {
  final dynamic id;
  final String? userId;
  final String title;
  final double amount;
  final String category;
  final String? note;
  final DateTime? expenseDate;
  final DateTime? createdAt;

  ExpenseModel({
    this.id,
    this.userId,
    required this.title,
    required this.amount,
    this.category = 'অন্যান্য',
    this.note,
    this.expenseDate,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'অন্যান্য',
      note: json['note']?.toString(),
      expenseDate: json['expense_date'] != null
          ? DateTime.tryParse(json['expense_date'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'amount': amount,
      'category': category,
      'note': note ?? '',
      'expense_date': (expenseDate ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (id != null) {
      data['id'] = id;
    }
    if (userId != null) {
      data['user_id'] = userId;
    }
    if (createdAt != null) {
      data['created_at'] = createdAt!.toUtc().toIso8601String();
    }
    return data;
  }
}
