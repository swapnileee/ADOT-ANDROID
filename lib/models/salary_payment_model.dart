class SalaryPaymentModel {
  final dynamic id;
  final String staffId;
  final String staffName;
  final double amountPaid;
  final DateTime paymentDate;
  final String monthYear; // e.g., 'July 2026'
  final String? notes;
  final DateTime? createdAt;

  SalaryPaymentModel({
    this.id,
    required this.staffId,
    required this.staffName,
    required this.amountPaid,
    required this.paymentDate,
    required this.monthYear,
    this.notes,
    this.createdAt,
  });

  factory SalaryPaymentModel.fromJson(Map<String, dynamic> json) {
    return SalaryPaymentModel(
      id: json['id'],
      staffId:
          json['staff_id']?.toString() ?? json['staffId']?.toString() ?? '',
      staffName:
          json['staff_name']?.toString() ?? json['staffName']?.toString() ?? '',
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ??
          (json['amountPaid'] as num?)?.toDouble() ??
          0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : (json['paymentDate'] != null
              ? DateTime.tryParse(json['paymentDate'].toString()) ??
                  DateTime.now()
              : DateTime.now()),
      monthYear:
          json['month_year']?.toString() ?? json['monthYear']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'staff_id': staffId,
      'staff_name': staffName,
      'amount_paid': amountPaid,
      'payment_date': paymentDate.toUtc().toIso8601String(),
      'month_year': monthYear,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}
