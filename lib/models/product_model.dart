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
  final double directBuyingPrice;
  final double directSellingPrice;
  final int directStockQuantity;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.supplier,
    required this.imageUrl,
    required this.baseUnit,
    this.directBuyingPrice = 0.0,
    this.directSellingPrice = 0.0,
    this.directStockQuantity = 0,
    required this.variants,
  });

  double get buyingPrice {
    if (directBuyingPrice > 0) return directBuyingPrice;
    if (variants.isNotEmpty) return minPrice * 0.75;
    return 0.0;
  }

  double get sellingPrice {
    if (directSellingPrice > 0) return directSellingPrice;
    if (variants.isNotEmpty) return minPrice;
    return 0.0;
  }

  int get stockQuantity {
    if (directStockQuantity > 0) return directStockQuantity;
    if (variants.isNotEmpty) return totalStock.toInt();
    return 0;
  }

  double get minPrice {
    if (variants.isNotEmpty) {
      return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    }
    return sellingPrice;
  }

  double get maxPrice {
    if (variants.isNotEmpty) {
      return variants.map((v) => v.price).reduce((a, b) => a > b ? a : b);
    }
    return sellingPrice;
  }

  double get totalStock {
    if (variants.isNotEmpty) {
      return variants.fold(0.0, (sum, v) => sum + v.stock);
    }
    return stockQuantity.toDouble();
  }

  /// Clean product title stripped of any hardcoded weight/volume parentheses strings.
  String get cleanName {
    return name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  double get unitProfit => sellingPrice - buyingPrice;
  double get stockInBaseUnit => totalStock;
  double get baseUnitPrice => sellingPrice;
  bool get allowDecimal => baseUnit.toLowerCase() == 'g' || baseUnit.toLowerCase() == 'ml' || baseUnit.toLowerCase() == 'kg' || baseUnit.toLowerCase() == 'l';
  UnitCategory get unitCategory => UnitConversionService.parseCategory(category.isNotEmpty ? category : baseUnit);

  String get formattedStock {
    final cleanVal = totalStock == totalStock.roundToDouble() ? totalStock.toInt().toString() : totalStock.toStringAsFixed(1);
    return '$cleanVal $baseUnit';
  }

  String get priceRangeText {
    if (variants.isNotEmpty) {
      final minP = minPrice;
      final maxP = maxPrice;
      if (minP == maxP) return '৳${minP.toStringAsFixed(0)}';
      return '৳${minP.toStringAsFixed(0)} - ৳${maxP.toStringAsFixed(0)}';
    }
    return '৳${sellingPrice.toStringAsFixed(0)}';
  }

  bool get isLowStock => totalStock <= 10;

  factory Product.fromJson(Map<String, dynamic> json) {
    List<ProductVariant> parsedVariants = [];
    if (json['variants'] != null && json['variants'] is List) {
      parsedVariants = (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v)))
          .toList();
    }

    final double buying = double.tryParse(json['buying_price']?.toString() ?? '0') ?? 0.0;
    final double rawSelling = double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0;
    final double baseUnitPriceVal = double.tryParse(json['base_unit_price']?.toString() ?? '0') ?? 0.0;
    final double selling = rawSelling > 0 ? rawSelling : baseUnitPriceVal;
    final int stock = int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? (int.tryParse(json['stock_in_base_unit']?.toString() ?? '0') ?? 0);

    // Fallback for legacy JSON structures when variants are missing
    if (parsedVariants.isEmpty && selling > 0) {
      final String unit = json['base_unit']?.toString() ?? 'pcs';
      parsedVariants = [
        ProductVariant(
          id: 'v_1',
          sizeLabel: '1 $unit',
          price: selling,
          stock: stock.toDouble(),
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
      directBuyingPrice: buying,
      directSellingPrice: selling,
      directStockQuantity: stock,
      variants: parsedVariants,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) => Product.fromJson(map);

  Map<String, dynamic> toDatabaseJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'category': category,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
    };
    if (supplier.isNotEmpty) {
      data['supplier'] = supplier;
    }
    if (imageUrl.isNotEmpty) {
      data['image_url'] = imageUrl;
    }
    if (variants.isNotEmpty) {
      data['variants'] = variants.map((v) => v.toJson()).toList();
    }
    return data;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'supplier': supplier,
      'image_url': imageUrl,
      'base_unit': baseUnit,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? supplier,
    String? imageUrl,
    String? baseUnit,
    double? directBuyingPrice,
    double? directSellingPrice,
    int? directStockQuantity,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      supplier: supplier ?? this.supplier,
      imageUrl: imageUrl ?? this.imageUrl,
      baseUnit: baseUnit ?? this.baseUnit,
      directBuyingPrice: directBuyingPrice ?? this.directBuyingPrice,
      directSellingPrice: directSellingPrice ?? this.directSellingPrice,
      directStockQuantity: directStockQuantity ?? this.directStockQuantity,
      variants: variants ?? this.variants,
    );
  }
}

/// Backwards compatibility alias
typedef ProductModel = Product;
