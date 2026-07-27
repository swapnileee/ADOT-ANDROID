import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';

class SupabaseService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // --- SEED ORGANIC STORE PRODUCTS (FALLBACK / INITIAL DATA) ---
  static final List<Product> _localSeedProducts = [
    Product(
      id: 'p_1',
      name: 'সরিষার তেল',
      category: 'তেল',
      supplier: 'ADOT Organic',
      imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400',
      baseUnit: 'ml',
      variants: [
        ProductVariant(id: 'v_101', sizeLabel: '250 ml', price: 250.0, stock: 40.0),
        ProductVariant(id: 'v_102', sizeLabel: '500 ml', price: 450.0, stock: 35.0),
        ProductVariant(id: 'v_103', sizeLabel: '1 L', price: 850.0, stock: 30.0),
        ProductVariant(id: 'v_104', sizeLabel: '2 L', price: 1650.0, stock: 20.0),
      ],
    ),
    Product(
      id: 'p_2',
      name: 'সুন্দরবনের খলিশা মধু',
      category: 'মধু',
      supplier: 'ADOT Honey Craft',
      imageUrl: 'https://images.unsplash.com/photo-1587049352847-4a222e784d38?w=400',
      baseUnit: 'g',
      variants: [
        ProductVariant(id: 'v_201', sizeLabel: '250 g', price: 400.0, stock: 25.0),
        ProductVariant(id: 'v_202', sizeLabel: '500 g', price: 750.0, stock: 30.0),
        ProductVariant(id: 'v_203', sizeLabel: '1 kg', price: 1400.0, stock: 15.0),
      ],
    ),
    Product(
      id: 'p_3',
      name: 'প্রাকৃতিক অর্গানিক লাল চাল',
      category: 'শস্য ও ডাল',
      supplier: 'ADOT Farmers Coop',
      imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400',
      baseUnit: 'kg',
      variants: [
        ProductVariant(id: 'v_301', sizeLabel: '1 kg', price: 120.0, stock: 100.0),
        ProductVariant(id: 'v_302', sizeLabel: '5 kg', price: 580.0, stock: 50.0),
        ProductVariant(id: 'v_303', sizeLabel: '10 kg', price: 1100.0, stock: 20.0),
      ],
    ),
    Product(
      id: 'p_4',
      name: 'দেশি মুক্ত হাসের ডিম',
      category: 'ডিম ও দুধ',
      supplier: 'ADOT Poultry',
      imageUrl: 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=400',
      baseUnit: 'pcs',
      variants: [
        ProductVariant(id: 'v_401', sizeLabel: '6 pcs', price: 95.0, stock: 50.0),
        ProductVariant(id: 'v_402', sizeLabel: '12 pcs', price: 185.0, stock: 40.0),
        ProductVariant(id: 'v_403', sizeLabel: '30 pcs', price: 450.0, stock: 15.0),
      ],
    ),
    Product(
      id: 'p_5',
      name: 'রাজশাহীর আমরূপালী আম',
      category: 'ফল',
      supplier: 'Rajshahi Orchards',
      imageUrl: 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=400',
      baseUnit: 'kg',
      variants: [
        ProductVariant(id: 'v_501', sizeLabel: '1 kg', price: 150.0, stock: 60.0),
        ProductVariant(id: 'v_502', sizeLabel: '3 kg', price: 420.0, stock: 30.0),
        ProductVariant(id: 'v_503', sizeLabel: '5 kg', price: 680.0, stock: 15.0),
      ],
    ),
  ];

  static List<Product> _inMemoryProducts = List.from(_localSeedProducts);
  static final List<SaleModel> _inMemorySales = [];
  static final List<ExpenseModel> _inMemoryExpenses = [];

  // --- CUSTOMER SYNC ---
  Future<void> syncCustomer(String customerName, {String? customerPhone}) async {
    if (customerName.trim().isEmpty || customerName.trim() == 'নগদ ক্রেতা') return;
    try {
      final client = _client;
      if (client != null) {
        final data = <String, dynamic>{
          'name': customerName.trim(),
          'last_purchase_at': DateTime.now().toIso8601String(),
        };
        if (customerPhone != null && customerPhone.trim().isNotEmpty) {
          data['phone'] = customerPhone.trim();
        }
        await client.from('customers').upsert(data, onConflict: 'name');
      }
    } catch (e) {
      debugPrint('Customer sync note: $e');
    }
  }

  // --- PRODUCTS ---
  Future<List<Product>> fetchProducts() async {
    try {
      final client = _client;
      if (client != null) {
        final response = await client.from('products').select('*').order('name', ascending: true);
        final list = (response as List).map((json) => Product.fromJson(json)).toList();
        if (list.isNotEmpty) {
          _inMemoryProducts = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('Supabase fetchProducts error: $e');
    }
    return _inMemoryProducts;
  }

  Future<void> addProduct(Product product) async {
    _inMemoryProducts.add(product);
    try {
      final client = _client;
      if (client != null) {
        await client.from('products').insert(product.toJson());
      }
    } catch (e) {
      debugPrint('Supabase addProduct error: $e');
    }
  }

  Future<void> updateProduct(Product product) async {
    final index = _inMemoryProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _inMemoryProducts[index] = product;
    }
    try {
      final client = _client;
      if (client != null) {
        await client.from('products').update(product.toJson()).eq('id', product.id);
      }
    } catch (e) {
      debugPrint('Supabase updateProduct error: $e');
    }
  }

  Future<void> updateProductStock(dynamic productId, num newStockInBaseUnit) async {
    final index = _inMemoryProducts.indexWhere((p) => p.id.toString() == productId.toString());
    if (index >= 0) {
      final p = _inMemoryProducts[index];
      if (p.variants.isNotEmpty) {
        final updatedVariants = p.variants.map((v) {
          return v.copyWith(stock: (v.stock > 0) ? (v.stock + newStockInBaseUnit / p.variants.length) : v.stock);
        }).toList();
        _inMemoryProducts[index] = p.copyWith(variants: updatedVariants);
      }
    }
  }

  Future<void> deductVariantStock({
    required String productId,
    required String variantId,
    required double quantityToDeduct,
  }) async {
    final index = _inMemoryProducts.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final p = _inMemoryProducts[index];
      final vIndex = p.variants.indexWhere((v) => v.id == variantId);
      if (vIndex >= 0) {
        final currentV = p.variants[vIndex];
        final newStock = (currentV.stock - quantityToDeduct) > 0 ? (currentV.stock - quantityToDeduct) : 0.0;
        final updatedVariants = List<ProductVariant>.from(p.variants);
        updatedVariants[vIndex] = currentV.copyWith(stock: newStock);
        final updatedProduct = p.copyWith(variants: updatedVariants);
        _inMemoryProducts[index] = updatedProduct;

        try {
          final client = _client;
          if (client != null) {
            await client.from('products').update(updatedProduct.toJson()).eq('id', productId);
          }
        } catch (e) {
          debugPrint('Supabase deductVariantStock error: $e');
        }
      }
    }
  }

  // --- SALES ---
  Future<List<SaleModel>> fetchSales() async {
    try {
      final client = _client;
      if (client != null) {
        try {
          final response = await client.from('sales').select('*').order('created_at', ascending: false);
          return (response as List).map((json) => SaleModel.fromJson(json)).toList();
        } catch (_) {
          final response = await client.from('orders').select('*').order('created_at', ascending: false);
          return (response as List).map((json) => SaleModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Supabase fetchSales error: $e');
    }
    return _inMemorySales;
  }

  Future<void> processSale({
    required SaleModel sale,
    required dynamic productId,
    required double currentStockInBaseUnit,
  }) async {
    _inMemorySales.insert(0, sale);
    try {
      final client = _client;
      if (client != null) {
        await client.from('sales').insert(sale.toJson());
      }
    } catch (e) {
      debugPrint('Supabase processSale error: $e');
    }
  }

  /// Process multiple cart items in a single checkout session.
  Future<void> processCartCheckout({
    required List<Map<String, dynamic>> cartItems,
    required String customerName,
    String? customerPhone,
    required double paidAmount,
    required double totalCartPrice,
    String paymentMethod = 'Cash',
  }) async {
    final double dueAmount = (totalCartPrice - paidAmount) > 0 ? (totalCartPrice - paidAmount) : 0.0;

    await syncCustomer(customerName, customerPhone: customerPhone);

    for (var item in cartItems) {
      final Product product = item['product'] as Product;
      final ProductVariant variant = item['variant'] as ProductVariant;
      final double qtyCount = (item['itemQuantity'] as num).toDouble();
      final double itemPrice = (item['totalPrice'] as num).toDouble();

      final sale = SaleModel(
        productName: '${product.cleanName} (${variant.sizeLabel})',
        variantId: variant.id,
        variantLabel: variant.sizeLabel,
        baseQuantity: qtyCount,
        displayQuantityWithUnit: '$qtyCount × ${variant.sizeLabel}',
        totalPrice: itemPrice,
        customerName: customerName,
        customerPhone: customerPhone,
        paidAmount: paidAmount > itemPrice ? itemPrice : paidAmount,
        dueAmount: dueAmount,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      );

      _inMemorySales.insert(0, sale);
      await deductVariantStock(
        productId: product.id,
        variantId: variant.id,
        quantityToDeduct: qtyCount,
      );

      try {
        final client = _client;
        if (client != null) {
          try {
            final response = await client.from('sales').insert(sale.toJson()).select();
            debugPrint('SUCCESS SUPABASE INSERT SALES: $response');
          } on PostgrestException catch (e) {
            debugPrint('SUPABASE POSTGREST ERROR ON sales: ${e.message} | Details: ${e.details} | Code: ${e.code}');
            if (e.code == '42P01' || e.message.contains('does not exist')) {
              try {
                final responseOrders = await client.from('orders').insert(sale.toJson()).select();
                debugPrint('SUCCESS SUPABASE INSERT ORDERS: $responseOrders');
              } on PostgrestException catch (e2) {
                debugPrint('SUPABASE POSTGREST ERROR ON orders fallback: ${e2.message}');
                rethrow;
              }
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        debugPrint('Supabase sales insert error: $e');
        rethrow;
      }
    }
  }

  /// Update due amount and paid amount for an existing sale
  Future<void> updateSaleDue({
    required dynamic saleId,
    required double newPaidAmount,
    required double newDueAmount,
  }) async {
    final cleanDue = newDueAmount < 0 ? 0.0 : newDueAmount;
    final status = cleanDue <= 0 ? 'paid' : 'due';

    final index = _inMemorySales.indexWhere((s) => s.id.toString() == saleId.toString());
    if (index >= 0) {
      final old = _inMemorySales[index];
      _inMemorySales[index] = SaleModel(
        id: old.id,
        productName: old.productName,
        variantId: old.variantId,
        variantLabel: old.variantLabel,
        quantity: old.quantity,
        baseQuantity: old.baseQuantity,
        displayQuantityWithUnit: old.displayQuantityWithUnit,
        totalPrice: old.totalPrice,
        customerName: old.customerName,
        paidAmount: newPaidAmount,
        dueAmount: cleanDue,
        paymentMethod: old.paymentMethod,
        createdAt: old.createdAt,
      );
    }

    try {
      final client = _client;
      if (client != null && saleId != null) {
        try {
          await client.from('sales').update({
            'paid_amount': newPaidAmount,
            'due_amount': cleanDue,
            'payment_status': status,
          }).eq('id', saleId);
        } catch (_) {
          await client.from('orders').update({
            'paid_amount': newPaidAmount,
            'due_amount': cleanDue,
            'payment_status': status,
          }).eq('id', saleId);
        }
      }
    } catch (e) {
      debugPrint('Supabase updateSaleDue error: $e');
      rethrow;
    }
  }

  // --- EXPENSES ---
  Future<List<ExpenseModel>> fetchExpenses() async {
    try {
      final client = _client;
      if (client != null) {
        final response = await client.from('expenses').select('*').order('created_at', ascending: false);
        return (response as List).map((json) => ExpenseModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Supabase fetchExpenses error: $e');
    }
    return _inMemoryExpenses;
  }

  Future<void> addExpense(ExpenseModel expense) async {
    _inMemoryExpenses.insert(0, expense);
    try {
      final client = _client;
      if (client != null) {
        await client.from('expenses').insert(expense.toJson());
      }
    } catch (e) {
      debugPrint('Supabase addExpense error: $e');
    }
  }

  // --- DASHBOARD METRICS ---
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final productsList = await fetchProducts();
    final salesList = await fetchSales();
    final expensesList = await fetchExpenses();

    final now = DateTime.now();
    double todaySalesTotal = 0.0;
    double todayCogsTotal = 0.0;

    for (var sale in salesList) {
      if (sale.createdAt != null &&
          sale.createdAt!.year == now.year &&
          sale.createdAt!.month == now.month &&
          sale.createdAt!.day == now.day) {
        todaySalesTotal += sale.totalPrice;
        todayCogsTotal += (sale.totalPrice * 0.70);
      }
    }

    double todayExpensesTotal = 0.0;
    for (var exp in expensesList) {
      if (exp.createdAt != null &&
          exp.createdAt!.year == now.year &&
          exp.createdAt!.month == now.month &&
          exp.createdAt!.day == now.day) {
        todayExpensesTotal += exp.amount;
      }
    }

    double totalDue = 0.0;
    for (var sale in salesList) {
      totalDue += sale.dueAmount;
    }

    int lowStockCount = 0;
    for (var p in productsList) {
      if (p.isLowStock) lowStockCount++;
    }

    double todayNetProfit = todaySalesTotal - todayExpensesTotal - todayCogsTotal;

    return {
      'todaySales': todaySalesTotal,
      'todayExpenses': todayExpensesTotal,
      'todayNetProfit': todayNetProfit,
      'totalDue': totalDue,
      'totalProducts': productsList.length,
      'lowStockCount': lowStockCount,
    };
  }
}
