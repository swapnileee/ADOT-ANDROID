class PurchaseModel {
  final dynamic id;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantLabel;
  final double quantityAdded;
  final double buyingPrice;
  final double totalCost;
  final String? supplierName;
  final String? notes;
  final DateTime? createdAt;

  PurchaseModel({
    this.id,
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantLabel,
    required this.quantityAdded,
    required this.buyingPrice,
    double? totalCost,
    this.supplierName,
    this.notes,
    this.createdAt,
  }) : totalCost = totalCost ?? (quantityAdded * buyingPrice);

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final double qty = (json['quantity_added'] as num?)?.toDouble() ??
        (json['quantityAdded'] as num?)?.toDouble() ??
        (json['quantity'] as num?)?.toDouble() ??
        1.0;
    final double price = (json['buying_price'] as num?)?.toDouble() ??
        (json['buyingPrice'] as num?)?.toDouble() ??
        0.0;
    final double total = (json['total_cost'] as num?)?.toDouble() ??
        (json['totalCost'] as num?)?.toDouble() ??
        (qty * price);

    return PurchaseModel(
      id: json['id'],
      productId: json['product_id']?.toString() ?? json['productId']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? json['productName']?.toString() ?? '',
      variantId: json['variant_id']?.toString() ?? json['variantId']?.toString(),
      variantLabel: json['variant_label']?.toString() ?? json['variantLabel']?.toString(),
      quantityAdded: qty,
      buyingPrice: price,
      totalCost: total,
      supplierName: json['supplier_name']?.toString() ?? json['supplierName']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'product_id': productId,
      'product_name': productName,
      'variant_id': variantId,
      'variant_label': variantLabel,
      'quantity_added': quantityAdded,
      'buying_price': buyingPrice,
      'total_cost': totalCost,
      'supplier_name': supplierName,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}
