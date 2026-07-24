class SaleModel {
  final dynamic id;
  final String productName;
  final int quantity;
  final double totalPrice;
  final String customerName;
  final double paidAmount;
  final double dueAmount;
  final DateTime? createdAt;

  SaleModel({
    this.id,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.customerName,
    required this.paidAmount,
    required this.dueAmount,
    this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'],
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customer_name']?.toString() ?? '',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      dueAmount: (json['due_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'product_name': productName,
      'quantity': quantity,
      'total_price': totalPrice,
      'customer_name': customerName,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
    };
    if (id != null) {
      data['id'] = id;
    }
    if (createdAt != null) {
      data['created_at'] = createdAt!.toIso8601String();
    }
    return data;
  }
}
