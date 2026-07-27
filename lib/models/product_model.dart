import '../services/unit_conversion_service.dart';

class ProductVariant {
  final String id;
  final String sizeLabel; // e.g., "250 ml", "500 ml", "1 L", "2 L"
  final double price;
  final double stock;

  ProductVariant({
    required this.id,
    required this.sizeLabel,
    required this.price,
    required this.stock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sizeLabel: json['size_label']?.toString() ?? json['sizeLabel']?.toString() ?? 'Default',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size_label': sizeLabel,
      'price': price,
      'stock': stock,
    };
  }

  ProductVariant copyWith({
    String? id,
    String? sizeLabel,
    double? price,
    double? stock,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      price: price ?? this.price,
      stock: stock ?? this.stock,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String category;
  final String supplier;
  final String imageUrl;
  final String baseUnit; // e.g., "ml", "g", "pcs", "L", "kg"
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.supplier,
    required this.imageUrl,
    required this.baseUnit,
    required this.variants,
  });

  double get minPrice => variants.isEmpty ? 0 : variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  double get maxPrice => variants.isEmpty ? 0 : variants.map((v) => v.price).reduce((a, b) => a > b ? a : b);
  double get totalStock => variants.fold(0.0, (sum, v) => sum + v.stock);

  /// Clean product title stripped of any hardcoded weight/volume parentheses strings.
  String get cleanName {
    return name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  // Backwards compatibility getters:
  double get sellingPrice => minPrice;
  double get buyingPrice => minPrice * 0.75;
  int get stockQuantity => totalStock.toInt();
  double get stockInBaseUnit => totalStock;
  double get baseUnitPrice => minPrice;
  bool get allowDecimal => baseUnit.toLowerCase() == 'g' || baseUnit.toLowerCase() == 'ml' || baseUnit.toLowerCase() == 'kg' || baseUnit.toLowerCase() == 'l';
  UnitCategory get unitCategory => UnitConversionService.parseCategory(category.isNotEmpty ? category : baseUnit);

  String get formattedStock {
    final cleanVal = totalStock == totalStock.roundToDouble() ? totalStock.toInt().toString() : totalStock.toStringAsFixed(1);
    return '$cleanVal $baseUnit';
  }

  String get priceRangeText {
    if (variants.isEmpty) return '৳0';
    if (minPrice == maxPrice) return '৳${minPrice.toStringAsFixed(0)}';
    return '৳${minPrice.toStringAsFixed(0)} - ৳${maxPrice.toStringAsFixed(0)}';
  }

  bool get isLowStock => totalStock <= 10;

  factory Product.fromJson(Map<String, dynamic> json) {
    List<ProductVariant> parsedVariants = [];
    if (json['variants'] != null && json['variants'] is List) {
      parsedVariants = (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v)))
          .toList();
    }

    // Fallback for legacy JSON structures
    if (parsedVariants.isEmpty) {
      final double price = (json['base_unit_price'] as num?)?.toDouble() ?? (json['selling_price'] as num?)?.toDouble() ?? 100.0;
      final double stock = (json['stock_in_base_unit'] as num?)?.toDouble() ?? (json['stock_quantity'] as num?)?.toDouble() ?? 10.0;
      final String unit = json['base_unit']?.toString() ?? 'pcs';
      parsedVariants = [
        ProductVariant(
          id: 'v_1',
          sizeLabel: '1 $unit',
          price: price,
          stock: stock,
        )
      ];
    }

    return Product(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'সাধারণ',
      supplier: json['supplier']?.toString() ?? 'ADOT Organic',
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      baseUnit: json['base_unit']?.toString() ?? json['baseUnit']?.toString() ?? 'pcs',
      variants: parsedVariants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'supplier': supplier,
      'image_url': imageUrl,
      'base_unit': baseUnit,
      'variants': variants.map((v) => v.toJson()).toList(),
      // Backwards compatibility database fields:
      'selling_price': minPrice,
      'stock_quantity': totalStock.toInt(),
      'stock_in_base_unit': totalStock,
      'base_unit_price': minPrice,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? supplier,
    String? imageUrl,
    String? baseUnit,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      imageUrl: imageUrl ?? this.imageUrl,
      baseUnit: baseUnit ?? this.baseUnit,
      variants: variants ?? this.variants,
    );
  }
}

/// Backwards compatibility alias
typedef ProductModel = Product;
