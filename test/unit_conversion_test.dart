import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/services/unit_conversion_service.dart';

void main() {
  group('UnitConversionService Tests', () {
    test('Dynamic Unit Options for Dropdown (Gram, Kg, ml, Liter, Count)', () {
      final weightOptions = UnitConversionService.getAvailableUnitOptions(UnitCategory.weight);
      expect(weightOptions.map((o) => o.label), ['Gram (g)', 'Kg (kilogram)']);

      final volumeOptions = UnitConversionService.getAvailableUnitOptions(UnitCategory.volume);
      expect(volumeOptions.map((o) => o.label), ['ml (milliliter)', 'L (liter)']);

      final countOptions = UnitConversionService.getAvailableUnitOptions(UnitCategory.count);
      expect(countOptions.map((o) => o.label), ['Piece', 'Packet', 'Dozen', 'Box', 'Carton']);
    });

    test('Weight unit conversion to base unit (grams)', () {
      expect(UnitConversionService.toBaseQuantity(1.5, 'kg', UnitCategory.weight), 1500.0);
      expect(UnitConversionService.toBaseQuantity(300, 'g', UnitCategory.weight), 300.0);
      expect(UnitConversionService.toBaseQuantity(1, 'kg', UnitCategory.weight), 1000.0);
    });

    test('Volume unit conversion to base unit (milliliters)', () {
      expect(UnitConversionService.toBaseQuantity(1.5, 'L', UnitCategory.volume), 1500.0);
      expect(UnitConversionService.toBaseQuantity(650, 'ml', UnitCategory.volume), 650.0);
      expect(UnitConversionService.toBaseQuantity(2, 'L', UnitCategory.volume), 2000.0);
    });

    test('Count unit conversion to base unit (pieces)', () {
      expect(UnitConversionService.toBaseQuantity(1, 'Dozen', UnitCategory.count), 12.0);
      expect(UnitConversionService.toBaseQuantity(2, 'Dozen', UnitCategory.count), 24.0);
      expect(UnitConversionService.toBaseQuantity(3, 'Piece', UnitCategory.count), 3.0);
      expect(UnitConversionService.toBaseQuantity(1, 'Packet', UnitCategory.count), 1.0);
    });

    test('Configurable Count Unit Multipliers', () {
      const customConfig = CountUnitConfig(
        packetMultiplier: 10.0,
        boxMultiplier: 50.0,
        cartonMultiplier: 100.0,
        dozenMultiplier: 12.0,
      );

      expect(UnitConversionService.toBaseQuantity(2, 'Packet', UnitCategory.count, config: customConfig), 20.0);
      expect(UnitConversionService.toBaseQuantity(1, 'Box', UnitCategory.count, config: customConfig), 50.0);
      expect(UnitConversionService.toBaseQuantity(1, 'Carton', UnitCategory.count, config: customConfig), 100.0);
    });

    test('Live Total Price Calculation Formula', () {
      // 300 g x ৳0.28 = ৳84
      final baseQty = UnitConversionService.toBaseQuantity(300, 'g', UnitCategory.weight);
      final totalPrice = UnitConversionService.calculateTotalPrice(baseQty, 0.28);
      expect(totalPrice, closeTo(84.0, 0.001));

      // 1.5 L x ৳0.19/ml = ৳285
      final baseVolumeQty = UnitConversionService.toBaseQuantity(1.5, 'L', UnitCategory.volume);
      final totalVolumePrice = UnitConversionService.calculateTotalPrice(baseVolumeQty, 0.19);
      expect(totalVolumePrice, closeTo(285.0, 0.001));
    });

    test('Opening Stock Helper Text Formatting', () {
      expect(UnitConversionService.formatOpeningStockHelper(5000, UnitCategory.weight), '5000 g = 5 kg');
      expect(UnitConversionService.formatOpeningStockHelper(10000, UnitCategory.volume), '10000 ml = 10 L');
      expect(UnitConversionService.formatOpeningStockHelper(25, UnitCategory.count), '25 pcs');
      expect(UnitConversionService.formatOpeningStockHelper(450, UnitCategory.weight), '450 g');
    });

    test('Human-Readable Stock Display Formatting', () {
      expect(UnitConversionService.formatStockDisplay(5000, UnitCategory.weight), '5 kg');
      expect(UnitConversionService.formatStockDisplay(450, UnitCategory.weight), '450 g');
      expect(UnitConversionService.formatStockDisplay(10000, UnitCategory.volume), '10 L');
      expect(UnitConversionService.formatStockDisplay(25, UnitCategory.count), '25 pcs');
    });
  });
}
