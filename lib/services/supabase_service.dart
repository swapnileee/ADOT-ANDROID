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

  Future<void> updateProductStock(dynamic productId, int newStock) async {
    await _client
        .from('products')
        .update({'stock_quantity': newStock})
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
    required int currentStock,
  }) async {
    if (currentStock < sale.quantity) {
      throw Exception("পর্যাপ্ত স্টক নেই! বর্তমান স্টক: $currentStock");
    }

    // 1. Record sale
    await _client.from('sales').insert(sale.toJson());

    // 2. Deduct stock
    final updatedStock = currentStock - sale.quantity;
    await updateProductStock(productId, updatedStock);
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
        .select('id, stock_quantity');

    final productsList = productsResponse as List;
    final totalProducts = productsList.length;
    int lowStockCount = 0;
    for (var row in productsList) {
      final stock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      if (stock <= 5) lowStockCount++;
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
