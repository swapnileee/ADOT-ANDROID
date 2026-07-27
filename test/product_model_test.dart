import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/models/product_model.dart';
import 'package:adot_shop_app/services/unit_conversion_service.dart';

void main() {
  group('ProductModel Tests & Backwards Compatibility', () {
    test('Legacy product JSON defaults seamlessly to Count category with pcs base unit', () {
      final legacyJson = {
        'id': 1,
        'name': 'সাবান',
        'category': 'প্রসাধন',
        'buying_price': 40.0,
        'selling_price': 55.0,
        'stock_quantity': 25,
      };

      final product = ProductModel.fromJson(legacyJson);

      expect(product.id, 1);
      expect(product.name, 'সাবান');
      expect(product.unitCategory, UnitCategory.count);
      expect(product.baseUnit, 'pcs');
      expect(product.baseUnitPrice, 55.0);
      expect(product.sellingPrice, 55.0);
      expect(product.stockInBaseUnit, 25.0);
      expect(product.stockQuantity, 25);
      expect(product.allowDecimal, false);
      expect(product.formattedStock, '25 pcs');
    });

    test('Multi-unit Weight product JSON parses correctly', () {
      final weightJson = {
        'id': 2,
        'name': 'আখের লাল চিনি',
        'category': 'মুদি',
        'buying_price': 0.20,
        'selling_price': 0.28,
        'stock_quantity': 5000,
        'unit_category': 'weight',
        'base_unit': 'g',
        'base_unit_price': 0.28,
        'stock_in_base_unit': 5000.0,
        'allow_decimal': true,
      };

      final product = ProductModel.fromJson(weightJson);

      expect(product.unitCategory, UnitCategory.weight);
      expect(product.baseUnit, 'g');
      expect(product.baseUnitPrice, 0.28);
      expect(product.stockInBaseUnit, 5000.0);
      expect(product.allowDecimal, true);
      expect(product.formattedStock, '5 kg');
    });

    test('Multi-unit Volume product JSON parses correctly', () {
      final volumeJson = {
        'id': 3,
        'name': 'সরিষার তেল',
        'category': 'মুদি',
        'buying_price': 0.15,
        'selling_price': 0.19,
        'stock_quantity': 10000,
        'unit_category': 'volume',
        'base_unit': 'ml',
        'base_unit_price': 0.19,
        'stock_in_base_unit': 10000.0,
        'allow_decimal': true,
      };

      final product = ProductModel.fromJson(volumeJson);

      expect(product.unitCategory, UnitCategory.volume);
      expect(product.baseUnit, 'ml');
      expect(product.baseUnitPrice, 0.19);
      expect(product.stockInBaseUnit, 10000.0);
      expect(product.allowDecimal, true);
      expect(product.formattedStock, '10 L');
    });

    test('toJson produces backwards compatible structure', () {
      final product = ProductModel(
        id: 10,
        name: 'সরিষার তেল',
        category: 'মুদি',
        buyingPrice: 0.15,
        unitCategory: UnitCategory.volume,
        baseUnit: 'ml',
        baseUnitPrice: 0.19,
        stockInBaseUnit: 1500.0,
        allowDecimal: true,
      );

      final json = product.toJson();

      expect(json['id'], 10);
      expect(json['name'], 'সরিষার তেল');
      expect(json['selling_price'], 0.19);
      expect(json['stock_quantity'], 1500);
      expect(json['unit_category'], 'volume');
      expect(json['base_unit'], 'ml');
      expect(json['base_unit_price'], 0.19);
      expect(json['stock_in_base_unit'], 1500.0);
      expect(json['allow_decimal'], true);
    });
  });
}
