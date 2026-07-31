import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device-Independent UTC Date Query Tests (BD Timezone +6h Offset)', () {
    test('Constructs valid BD start of today and start of yesterday boundaries with DateTime.utc', () {
      final DateTime nowBD = DateTime.now().toUtc().add(const Duration(hours: 6));
      final DateTime startOfTodayBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day);
      final DateTime startOfYesterdayBD = startOfTodayBD.subtract(const Duration(days: 1));

      final String startOfYesterdayUtcStr = startOfYesterdayBD.subtract(const Duration(hours: 6)).toIso8601String();
      final String startOfTodayUtcStr = startOfTodayBD.subtract(const Duration(hours: 6)).toIso8601String();

      // Verify valid ISO strings ending with Z (UTC)
      expect(startOfYesterdayUtcStr.endsWith('Z'), isTrue);
      expect(startOfTodayUtcStr.endsWith('Z'), isTrue);

      // Verify exactly 24 hours difference between start of yesterday and start of today
      final diff = startOfTodayBD.difference(startOfYesterdayBD);
      expect(diff.inHours, equals(24));
    });

    test('Exclusive upper bound (.lt) covers all yesterday timestamps up to midnight', () {
      final DateTime nowBD = DateTime.now().toUtc().add(const Duration(hours: 6));
      final DateTime startOfTodayBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day);
      final DateTime startOfYesterdayBD = startOfTodayBD.subtract(const Duration(days: 1));

      // A timestamp recorded at 23:59:59.999999 BD time yesterday
      final DateTime lateYesterdayBD = startOfTodayBD.subtract(const Duration(microseconds: 1));

      expect(lateYesterdayBD.isBefore(startOfTodayBD), isTrue);
      expect(lateYesterdayBD.isAfter(startOfYesterdayBD) || lateYesterdayBD.isAtSameMomentAs(startOfYesterdayBD), isTrue);
    });
  });
}
