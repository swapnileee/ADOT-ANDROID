class AppConstants {
  static const List<String> defaultCategories = [
    'সকল',
    'নিত্যপণ্য',
    'তেল',
    'ঘি',
    'মধু',
    'মসলা',
    'চাল',
    'ডাল',
    'ডিম',
    'দুধ',
    'ফল',
    'প্রসাধনী',
    'খেজুর',
    'সুপার ফুড',
    'সিজনাল',
    'অন্যান্য',
  ];

  /// List specifically for Add/Edit dropdown (excluding 'সকল')
  static List<String> get productDropdownCategories =>
      defaultCategories.where((c) => c != 'সকল').toList();
}
