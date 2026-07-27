import '../services/unit_conversion_service.dart';

class ProductModel {
  final dynamic id; // int or String depending on UUID / int sequence
  final String name;
  final String category;
  final double buyingPrice;
  final UnitCategory unitCategory;
  final String baseUnit;
  final double baseUnitPrice;
  final double stockInBaseUnit;
  final bool allowDecimal;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.buyingPrice,
    UnitCategory? unitCategory,
    String? baseUnit,
    double? baseUnitPrice,
    double? stockInBaseUnit,
    bool? allowDecimal,
    // Backwards compatibility constructor parameters:
    double? sellingPrice,
    int? stockQuantity,
  })  : baseUnitPrice = baseUnitPrice ?? sellingPrice ?? 0.0,
        stockInBaseUnit = stockInBaseUnit ?? (stockQuantity ?? 0).toDouble(),
        unitCategory = unitCategory ?? UnitCategory.count,
        baseUnit = baseUnit ?? UnitConversionService.getBaseUnit(unitCategory ?? UnitCategory.count),
        allowDecimal = allowDecimal ?? ((unitCategory ?? UnitCategory.count) != UnitCategory.count);

  /// Backwards compatibility getter for selling price.
  double get sellingPrice => baseUnitPrice;

  /// Backwards compatibility getter for stock quantity in integer units.
  int get stockQuantity => stockInBaseUnit.toInt();

  /// Formatted stock string in human-readable units (e.g. 5 kg, 500 g, 10 L, 25 pcs).
  String get formattedStock => UnitConversionService.formatStockDisplay(stockInBaseUnit, unitCategory);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final parsedCategory = json['unit_category'] != null
        ? UnitCategory.values.firstWhere(
            (e) => e.name == json['unit_category'].toString(),
            orElse: () => UnitCategory.count,
          )
        : UnitConversionService.parseCategory(json['category']?.toString());

    final parsedBaseUnit = json['base_unit']?.toString() ?? UnitConversionService.getBaseUnit(parsedCategory);

    final double parsedPrice = (json['base_unit_price'] as num?)?.toDouble() ??
        (json['selling_price'] as num?)?.toDouble() ??
        0.0;

    final double parsedStock = (json['stock_in_base_unit'] as num?)?.toDouble() ??
        (json['stock_quantity'] as num?)?.toDouble() ??
        0.0;

    final bool parsedAllowDecimal = (json['allow_decimal'] as bool?) ?? (parsedCategory != UnitCategory.count);

    return ProductModel(
      id: json['id'],
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      buyingPrice: (json['buying_price'] as num?)?.toDouble() ?? 0.0,
      unitCategory: parsedCategory,
      baseUnit: parsedBaseUnit,
      baseUnitPrice: parsedPrice,
      stockInBaseUnit: parsedStock,
      allowDecimal: parsedAllowDecimal,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'category': category,
      'buying_price': buyingPrice,
      'selling_price': baseUnitPrice,
      'stock_quantity': stockInBaseUnit.toInt(),
      'unit_category': unitCategory.name,
      'base_unit': baseUnit,
      'base_unit_price': baseUnitPrice,
      'stock_in_base_unit': stockInBaseUnit,
      'allow_decimal': allowDecimal,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }

  /// Low stock threshold based on unit category.
  bool get isLowStock {
    switch (unitCategory) {
      case UnitCategory.weight:
      case UnitCategory.volume:
        return stockInBaseUnit <= 5000; // <= 5 kg or <= 5 L
      case UnitCategory.count:
        return stockInBaseUnit <= 5; // <= 5 pcs
    }
  }

  /// Returns a copy of the product with updated fields.
  ProductModel copyWith({
    dynamic id,
    String? name,
    String? category,
    double? buyingPrice,
    UnitCategory? unitCategory,
    String? baseUnit,
    double? baseUnitPrice,
    double? stockInBaseUnit,
    bool? allowDecimal,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      unitCategory: unitCategory ?? this.unitCategory,
      baseUnit: baseUnit ?? this.baseUnit,
      baseUnitPrice: baseUnitPrice ?? this.baseUnitPrice,
      stockInBaseUnit: stockInBaseUnit ?? this.stockInBaseUnit,
      allowDecimal: allowDecimal ?? this.allowDecimal,
    );
  }
}
