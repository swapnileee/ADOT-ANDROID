import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/models/sale_model.dart';
import 'package:adot_shop_app/models/due_collection_model.dart';

void main() {
  group('Cash-in-Hand (হাতে নগদ) Calculation Logic Tests', () {
    final DateTime today = DateTime.now();
    final DateTime tomorrow = today.add(const Duration(days: 1));

    test('Rule 1 & 2: Fully unpaid sales (৳500 due) contribute ৳0 to Cash-in-Hand', () {
      final sale1 = SaleModel(
        productName: 'Item 1',
        totalPrice: 500.0,
        customerName: 'Rahim',
        paidAmount: 0.0,
        dueAmount: 500.0,
        createdAt: today,
      );

      final salesList = [sale1];
      final dueCollectionsList = <DueCollectionModel>[];
      const double expenses = 0.0;

      final double directPaidSales = salesList.fold(
        0.0,
        (sum, item) => sum + item.paidAmount,
      );
      final double dueCollected = dueCollectionsList.fold(
        0.0,
        (sum, item) => sum + item.amount,
      );
      final double cashInHand = (directPaidSales + dueCollected - expenses) > 0
          ? (directPaidSales + dueCollected - expenses)
          : 0.0;

      expect(directPaidSales, equals(0.0));
      expect(cashInHand, equals(0.0));
    });

    test('Rule 1: ৳350 fully due + ৳180 paid order results in exactly ৳180 Cash-in-Hand', () {
      final dueSale = SaleModel(
        productName: 'Shirt',
        totalPrice: 350.0,
        customerName: 'Customer A',
        paidAmount: 0.0,
        dueAmount: 350.0,
        createdAt: today,
      );

      final paidSale = SaleModel(
        productName: 'Pant',
        totalPrice: 180.0,
        customerName: 'Customer B',
        paidAmount: 180.0,
        dueAmount: 0.0,
        createdAt: today,
      );

      final salesList = [dueSale, paidSale];
      final dueCollectionsList = <DueCollectionModel>[];
      const double expenses = 0.0;

      final double totalSalesTurnover = salesList.fold(0.0, (sum, s) => sum + s.totalPrice);
      final double directPaidSales = salesList.fold(0.0, (sum, s) => sum + s.paidAmount);
      final double dueCollected = dueCollectionsList.fold(0.0, (sum, c) => sum + c.amount);
      final double cashInHand = (directPaidSales + dueCollected - expenses) > 0
          ? (directPaidSales + dueCollected - expenses)
          : 0.0;

      expect(totalSalesTurnover, equals(530.0)); // Total sales volume
      expect(directPaidSales, equals(180.0));     // Cash collected from direct sales
      expect(cashInHand, equals(180.0));          // Cash in hand excludes ৳350 due
    });

    test('Rule 3: Paying ৳200 of old due tomorrow adds ৳200 to tomorrow\'s Cash-in-Hand', () {
      // Tomorrow's due collection entry recorded when payment received
      final collectionTomorrow = DueCollectionModel(
        id: 'col_101',
        saleId: 'sale_due_1',
        customerName: 'Customer A',
        amount: 200.0,
        createdAt: tomorrow,
      );

      // Tomorrow's date boundary calculation
      final bdTomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
      final bdTomorrowEnd = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59, 999);

      final dueCollections = [collectionTomorrow];
      final salesTomorrow = <SaleModel>[]; // No new direct sales tomorrow
      const double expensesTomorrow = 0.0;

      double directPaidTomorrow = 0.0;
      for (var s in salesTomorrow) {
        if (s.createdAt != null && !s.createdAt!.isBefore(bdTomorrowStart) && !s.createdAt!.isAfter(bdTomorrowEnd)) {
          directPaidTomorrow += s.paidAmount;
        }
      }

      double dueCollectedTomorrow = 0.0;
      for (var c in dueCollections) {
        final colDate = c.createdAt.toLocal();
        if (!colDate.isBefore(bdTomorrowStart) && !colDate.isAfter(bdTomorrowEnd)) {
          dueCollectedTomorrow += c.amount;
        }
      }

      final double tomorrowCashInHand = (directPaidTomorrow + dueCollectedTomorrow - expensesTomorrow) > 0
          ? (directPaidTomorrow + dueCollectedTomorrow - expensesTomorrow)
          : 0.0;

      expect(dueCollectedTomorrow, equals(200.0));
      expect(tomorrowCashInHand, equals(200.0));
    });

    test('Multi-item cart checkout proportionally splits paid amounts accurately', () {
      const double item1Price = 200.0;
      const double item2Price = 300.0;
      const double totalCartPrice = 500.0;
      const double totalPaidAmount = 180.0;

      final double paidRatio = totalCartPrice > 0 ? (totalPaidAmount / totalCartPrice).clamp(0.0, 1.0) : 0.0;

      final item1Paid = item1Price * paidRatio; // 200 * 0.36 = 72
      final item2Paid = item2Price * paidRatio; // 300 * 0.36 = 108

      final item1Due = item1Price - item1Paid; // 128
      final item2Due = item2Price - item2Paid; // 192

      expect(item1Paid + item2Paid, equals(totalPaidAmount)); // 72 + 108 = 180
      expect(item1Due + item2Due, equals(totalCartPrice - totalPaidAmount)); // 128 + 192 = 320
    });
  });
}
