class SaleModel {
  final dynamic id;
  final String productName;
  final String? variantId;
  final String? variantLabel;
  final int quantity; // Integer base quantity representation for legacy compat
  final double baseQuantity; // Exact quantity in base unit (e.g. 1500 g, 1.5 L, 3 pcs)
  final String displayQuantityWithUnit; // User friendly string (e.g. "1.5 L", "300 g", "3 pcs")
  final double totalPrice;
  final String customerName;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final DateTime? createdAt;

  SaleModel({
    this.id,
    required this.productName,
    this.variantId,
    this.variantLabel,
    int? quantity,
    double? baseQuantity,
    String? displayQuantityWithUnit,
    required this.totalPrice,
    required this.customerName,
    required this.paidAmount,
    required this.dueAmount,
    this.paymentMethod = 'Cash',
    this.createdAt,
  })  : baseQuantity = baseQuantity ?? (quantity ?? 1).toDouble(),
        quantity = (baseQuantity ?? quantity ?? 1).toInt(),
        displayQuantityWithUnit = displayQuantityWithUnit ?? '${quantity ?? 1}টি';

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final double parsedBaseQty = (json['base_quantity'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        1.0;
    final int parsedQty = (json['quantity'] as num?)?.toInt() ?? parsedBaseQty.toInt();
    final String parsedDisplayUnit = json['display_quantity_with_unit']?.toString() ?? '$parsedQtyটি';

    return SaleModel(
      id: json['id'],
      productName: json['product_name']?.toString() ?? json['productName']?.toString() ?? '',
      variantId: json['variant_id']?.toString() ?? json['variantId']?.toString(),
      variantLabel: json['variant_label']?.toString() ?? json['variantLabel']?.toString(),
      quantity: parsedQty,
      baseQuantity: parsedBaseQty,
      displayQuantityWithUnit: parsedDisplayUnit,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? '',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      dueAmount: (json['due_amount'] as num?)?.toDouble() ?? (json['dueAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? json['paymentMethod']?.toString() ?? 'Cash',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'product_name': productName,
      'variant_id': variantId,
      'variant_label': variantLabel,
      'quantity': quantity,
      'base_quantity': baseQuantity,
      'display_quantity_with_unit': displayQuantityWithUnit,
      'total_price': totalPrice,
      'customer_name': customerName,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'payment_method': paymentMethod,
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
