import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/models/product_model.dart';

void main() {
  group('Variant-Based Product Architecture Tests', () {
    test('ProductVariant model instantiates and parses JSON correctly', () {
      final json = {
        'id': 'v_1',
        'size_label': '250 ml',
        'price': 250.0,
        'stock': 40.0,
      };

      final variant = ProductVariant.fromJson(json);

      expect(variant.id, 'v_1');
      expect(variant.sizeLabel, '250 ml');
      expect(variant.price, 250.0);
      expect(variant.stock, 40.0);
    });

    test('Product calculates minPrice, maxPrice, and totalStock across variants', () {
      final product = Product(
        id: 'p_1',
        name: 'সরিষার তেল',
        category: 'তেল',
        supplier: 'ADOT Organic',
        imageUrl: '',
        baseUnit: 'ml',
        variants: [
          ProductVariant(id: 'v_1', sizeLabel: '250 ml', price: 250.0, stock: 40.0),
          ProductVariant(id: 'v_2', sizeLabel: '500 ml', price: 450.0, stock: 35.0),
          ProductVariant(id: 'v_3', sizeLabel: '1 L', price: 850.0, stock: 25.0),
        ],
      );

      expect(product.minPrice, 250.0);
      expect(product.maxPrice, 850.0);
      expect(product.totalStock, 100.0);
      expect(product.priceRangeText, '৳250 - ৳850');
      expect(product.formattedStock, '100 ml');
    });

    test('Legacy product JSON without variants defaults seamlessly to a fallback variant', () {
      final legacyJson = {
        'id': 'p_legacy',
        'name': 'সাবান',
        'category': 'সাধারণ',
        'selling_price': 55.0,
        'stock_quantity': 25,
      };

      final product = Product.fromJson(legacyJson);

      expect(product.id, 'p_legacy');
      expect(product.name, 'সাবান');
      expect(product.variants.length, 1);
      expect(product.minPrice, 55.0);
      expect(product.totalStock, 25.0);
    });

    test('Product toJson produces complete variant list and backwards compatible fields', () {
      final product = Product(
        id: 'p_10',
        name: 'সুন্দরবনের মধু',
        category: 'মধু',
        supplier: 'ADOT Honey',
        imageUrl: '',
        baseUnit: 'g',
        variants: [
          ProductVariant(id: 'v_10', sizeLabel: '250 g', price: 400.0, stock: 20.0),
          ProductVariant(id: 'v_11', sizeLabel: '500 g', price: 750.0, stock: 30.0),
        ],
      );

      final json = product.toJson();

      expect(json['id'], 'p_10');
      expect(json['name'], 'সুন্দরবনের মধু');
      expect(json['category'], 'মধু');
      expect((json['variants'] as List).length, 2);
      expect(json['selling_price'], 400.0);
      expect(json['stock_quantity'], 50);
    });
  });
}
