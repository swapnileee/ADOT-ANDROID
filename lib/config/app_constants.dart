class AppConstants {
  static const List<String> defaultCategories = [
    'সকল',
    'নিত্যপণ্য',
    'তেল',
    'মধু',
    'ঘি',
    'মসলা',
    'চাল',
    'ডাল',
    'শস্য ও ডাল',
    'ডিম',
    'দুধ',
    'ডিম ও দুধ',
    'ফল',
    'প্রসাধনী',
    'অন্যান্য',
  ];

  /// List specifically for Add/Edit dropdown (excluding 'সকল')
  static List<String> get productDropdownCategories =>
      defaultCategories.where((c) => c != 'সকল').toList();
}
