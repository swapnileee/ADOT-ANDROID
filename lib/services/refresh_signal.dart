import 'package:flutter/foundation.dart';

/// Global RefreshSignal to notify screens when data changes (e.g. after a sale/order, expense, or stock change).
class RefreshSignal extends ChangeNotifier {
  static final RefreshSignal _instance = RefreshSignal._internal();
  factory RefreshSignal() => _instance;
  RefreshSignal._internal();

  int _version = 0;
  int get version => _version;

  /// Call this when a sale, expense, or product stock is created/updated/deleted.
  void notifyDataChanged() {
    _version++;
    notifyListeners();
  }
}
