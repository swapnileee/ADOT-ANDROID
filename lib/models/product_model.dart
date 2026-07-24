class ProductModel {
  final dynamic id; // int or String depending on UUID / int sequence
  final String name;
  final String category;
  final double buyingPrice;
  final double sellingPrice;
  final int stockQuantity;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.stockQuantity,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      buyingPrice: (json['buying_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'category': category,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }

  bool get isLowStock => stockQuantity <= 5;
}
