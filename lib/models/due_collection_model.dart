class DueCollectionModel {
  final String id;
  final String? saleId;
  final String customerName;
  final double amount;
  final DateTime createdAt;

  DueCollectionModel({
    required this.id,
    this.saleId,
    required this.customerName,
    required this.amount,
    required this.createdAt,
  });

  factory DueCollectionModel.fromJson(Map<String, dynamic> json) {
    return DueCollectionModel(
      id: json['id']?.toString() ?? '',
      saleId: json['sale_id']?.toString(),
      customerName: json['customer_name'] ?? json['name'] ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sale_id': saleId,
      'customer_name': customerName,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
