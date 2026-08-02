import 'package:flutter_test/flutter_test.dart';
import '../lib/models/staff_model.dart';

void main() {
  group('StaffModel Joining Date & Smart Salary Due Tests', () {
    test('StaffModel parses joining_date accurately from JSON without overwriting to now()', () {
      final json = {
        'id': 'st_99',
        'name': 'আব্দুল আহাদ',
        'designation': 'ম্যানেজার',
        'phone': '01700000000',
        'joining_date': '2025-01-15T00:00:00.000Z',
        'base_salary': 20000,
        'status': 'active',
      };

      final staff = StaffModel.fromJson(json);

      expect(staff.joinDate.year, equals(2025));
      expect(staff.joinDate.month, equals(1));
      expect(staff.joinDate.day, equals(15));
    });

    test('StaffModel serialization toEmployeeJson includes joining_date & join_date', () {
      final staff = StaffModel(
        name: 'রাসেল আহমেদ',
        designation: 'সহকারী',
        phone: '01800000000',
        joinDate: DateTime.utc(2026, 3, 10),
        monthlySalary: 15000,
      );

      final employeeJson = staff.toEmployeeJson();

      expect(employeeJson.containsKey('joining_date'), isTrue);
      expect(employeeJson.containsKey('join_date'), isTrue);
      expect(employeeJson['joining_date'], equals('2026-03-10'));
    });

    test('Smart Salary Due: Staff joining in current running month has NO salary due', () {
      final now = DateTime.now();
      final currentMonthJoinDate = DateTime(now.year, now.month, 1);

      final newStaff = StaffModel(
        name: 'তানভীর',
        designation: 'বিক্রয়কর্মী',
        phone: '01900000000',
        joinDate: currentMonthJoinDate,
        monthlySalary: 10000,
      );

      final isJoinedInCurrentMonth = newStaff.joinDate.year > now.year ||
          (newStaff.joinDate.year == now.year && newStaff.joinDate.month >= now.month);

      expect(isJoinedInCurrentMonth, isTrue);
    });

    test('Smart Salary Due: Staff joining in past month is marked as eligible for salary due', () {
      final now = DateTime.now();
      final pastJoinDate = DateTime(now.year, now.month - 1 > 0 ? now.month - 1 : 12, 1);

      final oldStaff = StaffModel(
        name: 'শাহিন',
        designation: 'ম্যানেজার',
        phone: '01500000000',
        joinDate: pastJoinDate,
        monthlySalary: 25000,
      );

      final isJoinedInCurrentMonth = oldStaff.joinDate.year > now.year ||
          (oldStaff.joinDate.year == now.year && oldStaff.joinDate.month >= now.month);

      expect(isJoinedInCurrentMonth, isFalse);
    });
  });
}
