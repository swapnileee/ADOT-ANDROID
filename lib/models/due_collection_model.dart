class DueCollectionModel {
  final String id;
  final String? saleId;
  final String customerName;
  final String? customerPhone;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  DueCollectionModel({
    required this.id,
    this.saleId,
    required this.customerName,
    this.customerPhone,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  factory DueCollectionModel.fromJson(Map<String, dynamic> json) {
    return DueCollectionModel(
      id: json['id']?.toString() ?? '',
      saleId: json['sale_id']?.toString(),
      customerName: json['customer_name'] ?? json['name'] ?? '',
      customerPhone: json['customer_phone']?.toString(),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now().toLocal())
          : DateTime.now().toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sale_id': saleId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
