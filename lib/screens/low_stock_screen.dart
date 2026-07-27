import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/unit_conversion_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<ProductModel> _lowStockProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLowStockProducts();
  }

  Future<void> _loadLowStockProducts() async {
    setState(() => _isLoading = true);
    try {
      final allProducts = await _supabaseService.fetchProducts();
      final lowStock = allProducts.where((p) => p.isLowStock).toList();

      if (!mounted) return;
      setState(() {
        _lowStockProducts = lowStock;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'কম স্টকের তালিকা লোড করতে সমস্যা: $e');
    }
  }

  void _showRestockDialog(ProductModel product) {
    final TextEditingController restockController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${product.name} - স্টক পুনর্নবীকরণ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('বর্তমান স্টক: ${product.formattedStock}'),
              const SizedBox(height: 12),
              TextField(
                controller: restockController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: product.allowDecimal,
                ),
                decoration: InputDecoration(
                  labelText: 'নতুন যুক্ত স্টক (${UnitConversionService.getBaseUnit(product.unitCategory)})',
                  hintText: 'যেমন: 1000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: () async {
                final added = double.tryParse(restockController.text.trim()) ?? 0.0;
                if (added <= 0) return;
                final newStock = product.stockInBaseUnit + added;
                Navigator.pop(context);
                try {
                  await _supabaseService.updateProductStock(product.id, newStock);
                  if (!context.mounted) return;
                  CustomSnackBar.showSuccess(context, 'স্টক সফলভাবে আপডেট হয়েছে!');
                  _loadLowStockProducts();
                } catch (e) {
                  if (!context.mounted) return;
                  CustomSnackBar.showError(context, 'স্টক আপডেট ব্যর্থ: $e');
                }
              },
              child: const Text('আপডেট করুন'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('কম স্টকের অ্যালার্ট (Low Stock)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLowStockProducts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadLowStockProducts,
                color: AppTheme.primaryGreen,
                child: Column(
                  children: [
                    // Alert Summary Banner
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'জরুরী স্টক অ্যালার্ট (${_lowStockProducts.length}টি পণ্য)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorRed,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'কম স্টকের সীমায় থাকা পণ্যসমূহ (Reorder Level Alert)',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Low Stock Items List
                    Expanded(
                      child: _lowStockProducts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 64, color: AppTheme.primaryGreen),
                                    SizedBox(height: 12),
                                    Text(
                                      'সব পণ্যের স্টক পর্যাপ্ত রয়েছে!',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'কোন পণ্যের স্টক কম স্টকের নিচে নেই',
                                      style: TextStyle(color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _lowStockProducts.length,
                              itemBuilder: (context, index) {
                                final product = _lowStockProducts[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorRed.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_rounded,
                                            color: AppTheme.errorRed,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'ক্যাটাগরি: ${product.category} | বিক্রয় মূল্য: ৳${product.baseUnitPrice.toStringAsFixed(2)}/${product.baseUnit}',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.errorRed,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${product.formattedStock} বাকি',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => _showRestockDialog(product),
                                              child: const Text(
                                                '+ স্টক যোগ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.primaryGreen,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
