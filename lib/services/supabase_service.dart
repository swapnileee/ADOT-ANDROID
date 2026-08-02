import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../models/purchase_model.dart';
import '../models/staff_model.dart';
import '../models/salary_payment_model.dart';
import '../models/due_collection_model.dart';

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
    Product(
      id: 'p_6',
      name: 'পাবনার গাওয়া ঘি',
      category: 'ঘি',
      supplier: 'Pabna Organic Dairy',
      imageUrl: 'https://images.unsplash.com/photo-1589927986089-35812388d1f4?w=400',
      baseUnit: 'g',
      variants: [
        ProductVariant(id: 'v_601', sizeLabel: '250 g', price: 450.0, stock: 20.0),
        ProductVariant(id: 'v_602', sizeLabel: '500 g', price: 850.0, stock: 15.0),
        ProductVariant(id: 'v_603', sizeLabel: '1 kg', price: 1650.0, stock: 10.0),
      ],
    ),
  ];

  static List<Product> _inMemoryProducts = List.from(_localSeedProducts);
  static List<SaleModel> _inMemorySales = [];
  static List<ExpenseModel> _inMemoryExpenses = [];
  static final List<PurchaseModel> _inMemoryPurchases = [];
  static List<StaffModel> _inMemoryStaff = [];
  static final List<SalaryPaymentModel> _inMemorySalaryPayments = [];

  List<Product> get cachedProducts => _inMemoryProducts;
  List<SaleModel> get cachedSales => _inMemorySales;
  List<ExpenseModel> get cachedExpenses => _inMemoryExpenses;
  List<PurchaseModel> get cachedPurchases => _inMemoryPurchases;
  List<StaffModel> get cachedStaff => _inMemoryStaff;
  List<SalaryPaymentModel> get cachedSalaryPayments => _inMemorySalaryPayments;
  List<DueCollectionModel> get cachedDueCollections => _inMemoryDueCollections;

  // --- CUSTOMER SYNC ---
  Future<void> syncCustomer({
    required String name,
    String phone = '',
    double dueAmount = 0.0,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    // Skip if no customer info or generic cash buyer without due
    if ((cleanName.isEmpty && cleanPhone.isEmpty) || (cleanName == 'নগদ ক্রেতা' && dueAmount <= 0)) return;

    try {
      final client = _client;
      if (client == null) return;

      List<dynamic> existingRows = [];

      // STRICT MATCH: Only search by phone number if available
      if (cleanPhone.isNotEmpty) {
        try {
          existingRows = await client.from('customers').select('*').eq('phone', cleanPhone);
        } catch (e) {
          debugPrint('Customer phone lookup error: $e');
        }
      }

      // If phone matches an existing customer, update them
      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final double currentDue = (existing['total_due'] as num?)?.toDouble() ?? 0.0;
        final double updatedDue = (currentDue + dueAmount < 0) ? 0.0 : (currentDue + dueAmount);

        await client.from('customers').update({
          'name': cleanName.isNotEmpty ? cleanName : existing['name'],
          'phone': cleanPhone,
          'total_due': updatedDue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', existing['id']);
        debugPrint('SUCCESS SUPABASE UPDATE CUSTOMER BY PHONE: ${existing['id']} | Due: $updatedDue');
      } else {
        // Create new customer record (For new phone OR blank phone with duplicate name)
        final inserted = await client.from('customers').insert({
          'name': cleanName.isEmpty ? 'নগদ ক্রেতা' : cleanName,
          'phone': cleanPhone.isEmpty ? null : cleanPhone,
          'total_due': dueAmount > 0 ? dueAmount : 0.0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).select().maybeSingle();
        debugPrint('SUCCESS SUPABASE INSERT NEW CUSTOMER RECORD: $inserted');
      }
    } catch (e, stack) {
      debugPrint('🚨 Error inside syncCustomer: $e');
      debugPrint('$stack');
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
          for (var p in list) {
            if ((p.name.contains('গাওয়া ঘি') || p.name.contains('ঘি')) && p.category != 'ঘি') {
              try {
                await client.from('products').update({'category': 'ঘি'}).eq('id', p.id);
              } catch (_) {}
            }
          }
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

  Future<void> addVariantStock({
    required String productId,
    required String variantId,
    required double quantityToAdd,
  }) async {
    final index = _inMemoryProducts.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      final p = _inMemoryProducts[index];
      final vIndex = p.variants.indexWhere((v) => v.id == variantId);
      if (vIndex >= 0) {
        final currentV = p.variants[vIndex];
        final newStock = currentV.stock + quantityToAdd;
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
          debugPrint('Supabase addVariantStock error: $e');
        }
      }
    }
  }

  // --- PURCHASES / STOCK IN ---
  Future<List<PurchaseModel>> fetchPurchases() async {
    try {
      final client = _client;
      if (client != null) {
        try {
          final response = await client.from('purchases').select('*').order('created_at', ascending: false);
          return (response as List).map((json) => PurchaseModel.fromJson(json)).toList();
        } catch (_) {
          final response = await client.from('stock_logs').select('*').order('created_at', ascending: false);
          return (response as List).map((json) => PurchaseModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Supabase fetchPurchases error: $e');
    }
    return _inMemoryPurchases;
  }

  Future<void> processStockIn({
    required PurchaseModel purchase,
  }) async {
    _inMemoryPurchases.insert(0, purchase);

    if (purchase.variantId != null && purchase.variantId!.isNotEmpty) {
      await addVariantStock(
        productId: purchase.productId,
        variantId: purchase.variantId!,
        quantityToAdd: purchase.quantityAdded,
      );
    }

    try {
      final client = _client;
      if (client != null) {
        try {
          await client.from('purchases').insert(purchase.toJson());
        } catch (_) {
          await client.from('stock_logs').insert(purchase.toJson());
        }
      }
    } catch (e) {
      debugPrint('Supabase processStockIn error: $e');
    }
  }

  // --- SALES ---
  Future<List<SaleModel>> fetchSales() async {
    try {
      final client = _client;
      if (client != null) {
        List<SaleModel> list;
        try {
          final response = await client.from('sales').select('*').order('created_at', ascending: false);
          list = (response as List).map((json) => SaleModel.fromJson(json)).toList();
        } catch (_) {
          final response = await client.from('orders').select('*').order('created_at', ascending: false);
          list = (response as List).map((json) => SaleModel.fromJson(json)).toList();
        }
        if (list.isNotEmpty) {
          _inMemorySales = list;
          return list;
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
    final double calculatedDue = (totalCartPrice - paidAmount) > 0 ? (totalCartPrice - paidAmount) : 0.0;
    final double paidRatio = totalCartPrice > 0 ? (paidAmount / totalCartPrice).clamp(0.0, 1.0) : 0.0;

    await syncCustomer(
      name: customerName,
      phone: customerPhone ?? '',
      dueAmount: calculatedDue,
    );

    for (var item in cartItems) {
      final Product product = item['product'] as Product;
      final ProductVariant variant = item['variant'] as ProductVariant;
      final double qtyCount = (item['itemQuantity'] as num).toDouble();
      final double itemPrice = (item['totalPrice'] as num).toDouble();
      final double itemPaid = itemPrice * paidRatio;
      final double itemDue = itemPrice - itemPaid > 0 ? itemPrice - itemPaid : 0.0;

      final sale = SaleModel(
        productName: '${product.cleanName} (${variant.sizeLabel})',
        variantId: variant.id,
        variantLabel: variant.sizeLabel,
        baseQuantity: qtyCount,
        displayQuantityWithUnit: '$qtyCount × ${variant.sizeLabel}',
        totalPrice: itemPrice,
        customerName: customerName,
        customerPhone: customerPhone,
        paidAmount: itemPaid,
        dueAmount: itemDue,
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

  /// Fetch all customers from Supabase customers table
  Future<List<Map<String, dynamic>>> fetchCustomers() async {
    try {
      final client = _client;
      if (client != null) {
        final response = await client.from('customers').select('*').order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response as List);
      }
    } catch (e) {
      debugPrint('Supabase fetchCustomers error: $e');
    }
    return [];
  }

  /// Record a custom/manual sale or due entry directly
  Future<void> recordSale(SaleModel sale) async {
    _inMemorySales.insert(0, sale);

    // Sync customer record
    if (sale.customerName.isNotEmpty || (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)) {
      await syncCustomer(
        name: sale.customerName,
        phone: sale.customerPhone ?? '',
        dueAmount: sale.dueAmount,
      );
    }

    final client = _client;
    if (client != null) {
      final payload = sale.toJson();
      if (payload['id'] == null || payload['id'] == '') {
        payload.remove('id');
      }
      try {
        await client.from('sales').insert(payload);
      } catch (e) {
        debugPrint('Supabase recordSale error on sales, fallback to orders: $e');
        try {
          await client.from('orders').insert(payload);
        } catch (_) {}
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
      final double dueDiff = cleanDue - old.dueAmount;

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
        customerPhone: old.customerPhone,
        paidAmount: newPaidAmount,
        dueAmount: cleanDue,
        paymentMethod: old.paymentMethod,
        createdAt: old.createdAt,
      );

      // Sync updated due to customers table
      if (old.customerName.isNotEmpty || (old.customerPhone != null && old.customerPhone!.isNotEmpty)) {
        await syncCustomer(
          name: old.customerName,
          phone: old.customerPhone ?? '',
          dueAmount: dueDiff,
        );
      }
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
        final userId = client.auth.currentUser?.id;
        dynamic response;
        if (userId != null) {
          response = await client
              .from('expenses')
              .select('*')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
        } else {
          response = await client
              .from('expenses')
              .select('*')
              .order('created_at', ascending: false);
        }
        final list = (response as List).map((json) => ExpenseModel.fromJson(json)).toList();
        if (list.isNotEmpty) {
          _inMemoryExpenses = list;
        }
        return list;
      }
    } catch (e) {
      debugPrint('Supabase fetchExpenses error: $e');
    }
    return _inMemoryExpenses;
  }

  Future<void> addExpense(ExpenseModel expense) async {
    _inMemoryExpenses.insert(0, expense);
    final client = _client;
    if (client != null) {
      final userId = client.auth.currentUser?.id;
      final payload = expense.toJson();
      if (userId != null && !payload.containsKey('user_id')) {
        payload['user_id'] = userId;
      }
      try {
        await client.from('expenses').insert(payload);
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204' || e.message.contains('PGRST204') || e.message.contains('category') || e.message.contains('note')) {
          debugPrint('Supabase addExpense PostgrestException PGRST204 fallback: ${e.message}');
          final safePayload = Map<String, dynamic>.from(payload)
            ..remove('category')
            ..remove('note');
          await client.from('expenses').insert(safePayload);
        } else {
          debugPrint('Supabase addExpense PostgrestException error: $e');
          rethrow;
        }
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('PGRST204') || errStr.contains('category') || errStr.contains('note')) {
          debugPrint('Supabase addExpense error fallback: $e');
          final safePayload = Map<String, dynamic>.from(payload)
            ..remove('category')
            ..remove('note');
          await client.from('expenses').insert(safePayload);
        } else {
          debugPrint('Supabase addExpense error: $e');
          rethrow;
        }
      }
    }
  }

  Future<void> deleteExpense(dynamic id) async {
    _inMemoryExpenses.removeWhere((e) => e.id == id);
    try {
      final client = _client;
      if (client != null && id != null) {
        await client.from('expenses').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Supabase deleteExpense error: $e');
      rethrow;
    }
  }

  // --- DIRECT DATE-BOUNDED ORDER QUERIES (avoids unfiltered list iteration) ---

  /// Fetches today's sales stats directly using Supabase RPC function `get_today_sales_dhaka`.
  /// Timezone logic is handled entirely by the PostgreSQL function (Asia/Dhaka) or UTC fallback.
  Future<Map<String, dynamic>> fetchTodayOrderStats() async {
    double totalSales = 0.0;
    double paidSales = 0.0;
    int orderCount = 0;
    double totalCogs = 0.0;
    int dueCustomers = 0;

    final DateTime nowBD = DateTime.now().toUtc().add(const Duration(hours: 6));
    final DateTime startOfTodayBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day);
    final String startOfTodayUtcStr = startOfTodayBD.subtract(const Duration(hours: 6)).toIso8601String();
    final String nowUtcStr = DateTime.now().toUtc().toIso8601String();

    try {
      final client = _client;
      if (client != null) {
        dynamic response;
        try {
          response = await client.rpc('get_today_sales_dhaka').single();
        } catch (_) {
          try {
            response = await client.rpc('get_today_sales_bd');
            if (response is List && response.isNotEmpty) {
              response = response[0];
            }
          } catch (_) {
            // Direct query fallback for Today's Sales
            try {
              final directResponse = await client
                  .from('sales')
                  .select('total_amount, total_price, paid_amount')
                  .gte('created_at', startOfTodayUtcStr)
                  .lte('created_at', nowUtcStr);
              if (directResponse.isNotEmpty) {
                double tot = 0.0;
                double paid = 0.0;
                for (var row in directResponse) {
                  tot += ((row['total_amount'] ?? row['total_price']) as num?)?.toDouble() ?? 0.0;
                  paid += (row['paid_amount'] as num?)?.toDouble() ?? 0.0;
                }
                totalSales = tot;
                paidSales = paid;
                orderCount = directResponse.length;
              }
            } catch (_) {}
          }
        }

        if (response != null && response is Map) {
          totalSales = ((response['total_sales'] ?? response['today_total'] ?? response['total_amount'] ?? response['total_price']) as num?)?.toDouble() ?? totalSales;
          paidSales = ((response['paid_sales'] ?? response['total_paid'] ?? response['paid_amount'] ?? response['today_paid']) as num?)?.toDouble() ?? paidSales;
          orderCount = ((response['order_count'] ?? response['today_count'] ?? response['count']) as num?)?.toInt() ?? orderCount;
          totalCogs = ((response['total_cogs'] ?? response['cogs'] ?? response['today_cogs']) as num?)?.toDouble() ?? 0.0;
          dueCustomers = ((response['due_customers'] ?? response['due_count']) as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      debugPrint('fetchTodayOrderStats error: $e');
    }

    return {
      'totalSales': totalSales,
      'paidSales': paidSales,
      'orderCount': orderCount,
      'totalCogs': totalCogs,
      'dueCustomers': dueCustomers,
    };
  }

  /// Fetches yesterday's sales total using exact UTC-converted BD local midnight bounds.
  Future<double> fetchYesterdayOrderTotal() async {
    final DateTime nowBD = DateTime.now().toUtc().add(const Duration(hours: 6));
    final DateTime startOfTodayBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day);
    final DateTime startOfYesterdayBD = startOfTodayBD.subtract(const Duration(days: 1));

    final String startOfYesterdayUtcStr = startOfYesterdayBD.subtract(const Duration(hours: 6)).toIso8601String();
    final String startOfTodayUtcStr = startOfTodayBD.subtract(const Duration(hours: 6)).toIso8601String();

    double total = 0.0;
    try {
      final client = _client;
      if (client != null) {
        dynamic response;
        try {
          response = await client
              .from('sales')
              .select('total_amount, total_price')
              .gte('created_at', startOfYesterdayUtcStr)
              .lt('created_at', startOfTodayUtcStr);
        } catch (_) {
          response = await client
              .from('orders')
              .select('total_amount, total_price')
              .gte('created_at', startOfYesterdayUtcStr)
              .lt('created_at', startOfTodayUtcStr);
        }

        if (response is List) {
          for (var row in response) {
            total += ((row['total_amount'] ?? row['total_price']) as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('fetchYesterdayOrderTotal error: $e');
    }
    return total;
  }

  // --- DASHBOARD METRICS ---

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final productsList = await fetchProducts();
    final salesList = await fetchSales();
    final expensesList = await fetchExpenses();
    final dueCollectionsList = await fetchDueCollections();

    final now = DateTime.now();
    double todaySalesTotal = 0.0;
    double todayPaidSalesTotal = 0.0;
    double todayCogsTotal = 0.0;
    int todayOrderCount = 0;

    for (var sale in salesList) {
      if (sale.createdAt != null) {
        final saleDate = sale.createdAt!.toLocal();
        if (saleDate.year == now.year &&
            saleDate.month == now.month &&
            saleDate.day == now.day) {
          todaySalesTotal += sale.totalPrice;
          todayPaidSalesTotal += sale.paidAmount;
          todayCogsTotal += (sale.totalPrice * 0.70);
          todayOrderCount++;
        }
      }
    }

    double todayDueCollected = 0.0;
    for (var col in dueCollectionsList) {
      final colDate = col.createdAt.toLocal();
      if (colDate.year == now.year &&
          colDate.month == now.month &&
          colDate.day == now.day) {
        todayDueCollected += col.amount;
      }
    }

    double todayExpensesTotal = 0.0;
    for (var exp in expensesList) {
      final expDate = (exp.expenseDate ?? exp.createdAt)?.toLocal();
      if (expDate != null &&
          expDate.year == now.year &&
          expDate.month == now.month &&
          expDate.day == now.day) {
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
    double cashInHand = (todayPaidSalesTotal + todayDueCollected - todayExpensesTotal) > 0
        ? (todayPaidSalesTotal + todayDueCollected - todayExpensesTotal)
        : 0.0;

    return {
      'todaySales': todaySalesTotal,
      'todayPaidSales': todayPaidSalesTotal,
      'todayDueCollected': todayDueCollected,
      'cashInHand': cashInHand,
      'todayExpenses': todayExpensesTotal,
      'todayNetProfit': todayNetProfit,
      'totalDue': totalDue,
      'totalProducts': productsList.length,
      'lowStockCount': lowStockCount,
      'todayOrderCount': todayOrderCount,
    };
  }

  /// Fetches comprehensive monthly/date-bounded report statistics:
  /// 1. Total Sales Turnover & Transaction Count
  /// 2. Direct Sales Paid Amount & New Due Generated
  /// 3. Old Due Collections Amount (from due_collections table)
  /// 4. Total Cash Collected (Direct Paid Sales + Old Due Collected)
  /// 5. Expenses Breakdown by Category (e.g., shop rent, utility bills, salary)
  Future<Map<String, dynamic>> fetchMonthlyReportMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final salesList = await fetchSales();
    final expensesList = await fetchExpenses();
    final dueCollectionsList = await fetchDueCollections();

    final DateTime startLocal = startDate.toLocal();
    final DateTime endLocal = endDate.toLocal();

    double totalSalesTurnover = 0.0;
    double directPaidSales = 0.0;
    double newDueGenerated = 0.0;
    int salesCount = 0;

    final List<SaleModel> filteredSales = [];

    for (var sale in salesList) {
      final saleDate = sale.createdAt?.toLocal();
      if (saleDate != null &&
          (saleDate.isAfter(startLocal) || saleDate.isAtSameMomentAs(startLocal)) &&
          (saleDate.isBefore(endLocal) || saleDate.isAtSameMomentAs(endLocal))) {
        filteredSales.add(sale);
        totalSalesTurnover += sale.totalPrice;
        directPaidSales += sale.paidAmount;
        newDueGenerated += sale.dueAmount;
        salesCount++;
      }
    }

    double oldDueCollected = 0.0;
    final List<DueCollectionModel> filteredDueCollections = [];

    for (var col in dueCollectionsList) {
      final colDate = col.createdAt.toLocal();
      if ((colDate.isAfter(startLocal) || colDate.isAtSameMomentAs(startLocal)) &&
          (colDate.isBefore(endLocal) || colDate.isAtSameMomentAs(endLocal))) {
        filteredDueCollections.add(col);
        oldDueCollected += col.amount;
      }
    }

    final double totalCashCollected = directPaidSales + oldDueCollected;

    double totalExpenses = 0.0;
    final Map<String, double> expensesByCategory = {};
    final List<ExpenseModel> filteredExpenses = [];

    for (var exp in expensesList) {
      final expDate = (exp.expenseDate ?? exp.createdAt)?.toLocal();
      if (expDate != null &&
          (expDate.isAfter(startLocal) || expDate.isAtSameMomentAs(startLocal)) &&
          (expDate.isBefore(endLocal) || expDate.isAtSameMomentAs(endLocal))) {
        filteredExpenses.add(exp);
        totalExpenses += exp.amount;

        final String categoryKey = exp.category.trim().isEmpty ? 'অন্যান্য' : exp.category.trim();
        expensesByCategory[categoryKey] = (expensesByCategory[categoryKey] ?? 0.0) + exp.amount;
      }
    }

    return {
      'totalSalesTurnover': totalSalesTurnover,
      'directPaidSales': directPaidSales,
      'oldDueCollected': oldDueCollected,
      'totalCashCollected': totalCashCollected,
      'newDueGenerated': newDueGenerated,
      'totalExpenses': totalExpenses,
      'expensesByCategory': expensesByCategory,
      'salesCount': salesCount,
      'filteredSales': filteredSales,
      'filteredExpenses': filteredExpenses,
      'filteredDueCollections': filteredDueCollections,
    };
  }

  // --- STAFF & SALARY MANAGEMENT ---
  Future<List<StaffModel>> fetchStaff() async {
    try {
      final client = _client;
      if (client != null) {
        try {
          final response = await client.from('employees').select('*').order('created_at', ascending: false);
          final list = (response as List).map((json) => StaffModel.fromJson(json)).toList();
          _inMemoryStaff = list;
          return list;
        } catch (e) {
          debugPrint('Supabase fetchStaff on employees table failed, trying staff table: $e');
        }

        try {
          final responseStaff = await client.from('staff').select('*').order('name', ascending: true);
          final listStaff = (responseStaff as List).map((json) => StaffModel.fromJson(json)).toList();
          _inMemoryStaff = listStaff;
          return listStaff;
        } catch (e2) {
          debugPrint('Supabase fetchStaff on staff table failed: $e2');
        }
      }
    } catch (e) {
      debugPrint('Supabase fetchStaff error: $e');
    }
    return _inMemoryStaff;
  }

  Future<StaffModel?> addStaff(StaffModel staff) async {
    try {
      final client = _client;
      if (client != null) {
        final payload = staff.toEmployeeJson();
        dynamic response;
        try {
          response = await client.from('employees').insert(payload).select().single();
        } catch (e) {
          debugPrint('Supabase addStaff insert error, retrying without join_date: $e');
          final fallback = Map<String, dynamic>.from(payload)..remove('join_date');
          try {
            response = await client.from('employees').insert(fallback).select().single();
          } catch (e2) {
            debugPrint('Supabase addStaff on employees error, fallback to staff: $e2');
            final fallbackPayload = staff.toJson();
            if (fallbackPayload['id'] != null && fallbackPayload['id'].toString().startsWith('st_')) {
              fallbackPayload.remove('id');
            }
            try {
              response = await client.from('staff').insert(fallbackPayload).select().single();
            } catch (_) {}
          }
        }
        if (response != null) {
          final newStaff = StaffModel.fromJson(response);
          _inMemoryStaff.insert(0, newStaff);
          return newStaff;
        }
      }
    } catch (e) {
      debugPrint('Supabase addStaff error: $e');
    }
    _inMemoryStaff.insert(0, staff);
    return staff;
  }

  Future<void> updateStaff(StaffModel staff) async {
    final index = _inMemoryStaff.indexWhere((s) => s.id.toString() == staff.id.toString());
    if (index >= 0) {
      _inMemoryStaff[index] = staff;
    }
    try {
      final client = _client;
      if (client != null && staff.id != null) {
        final payload = staff.toEmployeeJson();
        try {
          await client.from('employees').update(payload).eq('id', staff.id);
        } catch (e) {
          debugPrint('Supabase updateStaff employees error, retrying without join_date: $e');
          final safePayload = Map<String, dynamic>.from(payload)..remove('join_date');
          try {
            await client.from('employees').update(safePayload).eq('id', staff.id);
          } catch (_) {}
        }
        try {
          await client.from('staff').update(staff.toJson()).eq('id', staff.id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase updateStaff error: $e');
    }
  }

  Future<List<SalaryPaymentModel>> fetchSalaryPayments() async {
    try {
      final client = _client;
      if (client != null) {
        final response = await client.from('salary_payments').select('*').order('created_at', ascending: false);
        final list = (response as List).map((json) => SalaryPaymentModel.fromJson(json)).toList();
        if (list.isNotEmpty) {
          _inMemorySalaryPayments.clear();
          _inMemorySalaryPayments.addAll(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('Supabase fetchSalaryPayments error: $e');
    }
    return _inMemorySalaryPayments;
  }

  Future<void> processSalaryPayment({
    required SalaryPaymentModel payment,
    bool addAsExpense = true,
  }) async {
    _inMemorySalaryPayments.insert(0, payment);

    try {
      final client = _client;
      if (client != null) {
        try {
          await client.from('salary_payments').insert(payment.toJson());
        } catch (e) {
          debugPrint('Supabase processSalaryPayment insert error: $e');
        }

        // Update employee pending_salary in Supabase
        try {
          await client.from('employees').update({
            'pending_salary': 0.0,
          }).eq('id', payment.staffId);
        } catch (_) {}
        try {
          await client.from('staff').update({
            'status': 'paid',
          }).eq('id', payment.staffId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase processSalaryPayment error: $e');
    }

    if (addAsExpense) {
      await addExpense(ExpenseModel(
        title: '[কর্মচারী বেতন] ${payment.staffName} - ${payment.monthYear}',
        amount: payment.amountPaid,
        category: 'Salary',
        note: payment.notes ?? 'কর্মচারী বেতন প্রদান',
        createdAt: payment.paymentDate,
      ));
    }
  }

  // --- DUE COLLECTIONS / REPAYMENTS ---
  static final List<DueCollectionModel> _inMemoryDueCollections = [];

  Future<List<DueCollectionModel>> fetchDueCollections() async {
    try {
      final client = _client;
      if (client != null) {
        final response = await client
            .from('due_collections')
            .select('*')
            .order('created_at', ascending: false);
        final list = (response as List).map((json) => DueCollectionModel.fromJson(json)).toList();
        if (list.isNotEmpty) {
          _inMemoryDueCollections.clear();
          _inMemoryDueCollections.addAll(list);
        }
        return list;
      }
    } catch (e) {
      debugPrint('Supabase fetchDueCollections error: $e');
    }
    return _inMemoryDueCollections;
  }

  Future<void> recordDueCollection({
    required String customerName,
    required double amount,
    String? saleId,
  }) async {
    final entry = DueCollectionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      saleId: saleId,
      customerName: customerName,
      amount: amount,
      createdAt: DateTime.now(),
    );
    _inMemoryDueCollections.insert(0, entry);

    try {
      final client = _client;
      if (client != null) {
        await client.from('due_collections').insert(entry.toJson());
      }
    } catch (e) {
      debugPrint('Supabase recordDueCollection error (fallback to in-memory): $e');
    }
  }
}
