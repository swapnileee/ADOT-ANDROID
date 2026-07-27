import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- PRODUCTS ---
  Future<List<ProductModel>> fetchProducts() async {
    final response = await _client
        .from('products')
        .select('*')
        .order('name', ascending: true);

    return (response as List).map((json) => ProductModel.fromJson(json)).toList();
  }

  Future<void> addProduct(ProductModel product) async {
    await _client.from('products').insert(product.toJson());
  }

  Future<void> updateProduct(ProductModel product) async {
    if (product.id == null) return;
    await _client.from('products').update(product.toJson()).eq('id', product.id);
  }

  Future<void> updateProductStock(dynamic productId, num newStockInBaseUnit) async {
    await _client
        .from('products')
        .update({
          'stock_in_base_unit': newStockInBaseUnit.toDouble(),
          'stock_quantity': newStockInBaseUnit.toInt(),
        })
        .eq('id', productId);
  }

  // --- SALES ---
  Future<List<SaleModel>> fetchSales() async {
    final response = await _client
        .from('sales')
        .select('*')
        .order('created_at', ascending: false);

    return (response as List).map((json) => SaleModel.fromJson(json)).toList();
  }

  Future<void> processSale({
    required SaleModel sale,
    required dynamic productId,
    required double currentStockInBaseUnit,
  }) async {
    if (currentStockInBaseUnit < sale.baseQuantity) {
      throw Exception("পর্যাপ্ত স্টক নেই! বর্তমান স্টক: $currentStockInBaseUnit");
    }

    // 1. Record sale
    await _client.from('sales').insert(sale.toJson());

    // 2. Deduct stock
    final updatedStock = currentStockInBaseUnit - sale.baseQuantity;
    await updateProductStock(productId, updatedStock);
  }

  /// Process multiple cart items in a single checkout session.
  Future<void> processCartCheckout({
    required List<Map<String, dynamic>> cartItems,
    required String customerName,
    required double paidAmount,
    required double totalCartPrice,
  }) async {
    final double dueAmount = (totalCartPrice - paidAmount) > 0 ? (totalCartPrice - paidAmount) : 0.0;

    for (var item in cartItems) {
      final ProductModel product = item['product'] as ProductModel;
      final double baseQty = (item['baseQuantity'] as num).toDouble();
      final String displayQtyWithUnit = item['displayQtyWithUnit'].toString();
      final double itemPrice = (item['totalPrice'] as num).toDouble();

      final sale = SaleModel(
        productName: product.name,
        baseQuantity: baseQty,
        displayQuantityWithUnit: displayQtyWithUnit,
        totalPrice: itemPrice,
        customerName: customerName,
        paidAmount: paidAmount > itemPrice ? itemPrice : paidAmount,
        dueAmount: dueAmount,
      );

      await processSale(
        sale: sale,
        productId: product.id,
        currentStockInBaseUnit: product.stockInBaseUnit,
      );
    }
  }

  // --- EXPENSES ---
  Future<List<ExpenseModel>> fetchExpenses() async {
    final response = await _client
        .from('expenses')
        .select('*')
        .order('created_at', ascending: false);

    return (response as List).map((json) => ExpenseModel.fromJson(json)).toList();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _client.from('expenses').insert(expense.toJson());
  }

  // --- DASHBOARD METRICS ---
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

    // 1. Today's Sales
    final salesResponse = await _client
        .from('sales')
        .select('*')
        .gte('created_at', startOfToday);

    double todaySalesTotal = 0.0;
    for (var row in (salesResponse as List)) {
      todaySalesTotal += (row['total_price'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Today's Expenses
    final expensesResponse = await _client
        .from('expenses')
        .select('*')
        .gte('created_at', startOfToday);

    double todayExpensesTotal = 0.0;
    for (var row in (expensesResponse as List)) {
      todayExpensesTotal += (row['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 3. Total Due Across All Sales
    final allSalesResponse = await _client
        .from('sales')
        .select('due_amount');

    double totalDue = 0.0;
    for (var row in (allSalesResponse as List)) {
      totalDue += (row['due_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 4. Total Product Count & Low Stock Count
    final productsResponse = await _client
        .from('products')
        .select('*');

    final productsList = (productsResponse as List).map((json) => ProductModel.fromJson(json)).toList();
    final totalProducts = productsList.length;
    int lowStockCount = 0;
    for (var product in productsList) {
      if (product.isLowStock) lowStockCount++;
    }

    return {
      'todaySales': todaySalesTotal,
      'todayExpenses': todayExpensesTotal,
      'totalDue': totalDue,
      'totalProducts': totalProducts,
      'lowStockCount': lowStockCount,
    };
  }
}
