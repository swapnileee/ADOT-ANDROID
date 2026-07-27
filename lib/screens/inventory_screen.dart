import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/unit_conversion_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _supabaseService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ইনভেন্টরি লোড করতে ব্যর্থ হয়েছে: $e');
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _openAddProductScreen({ProductModel? productToEdit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(productToEdit: productToEdit),
      ),
    );

    if (result == true) {
      _loadProducts();
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
                  labelText: 'নতুন নতুন যুক্ত স্টক (${UnitConversionService.getBaseUnit(product.unitCategory)})',
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
                  CustomSnackBar.showSuccess(context, 'স্টক সফলভাবে আপডেট হয়েছে!');
                  _loadProducts();
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
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'মেনু খুলুন',
        ),
        title: const Text('ইনভেন্টরি ও পণ্য তালিকা'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddProductScreen(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text(
          'নতুন পণ্য',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                onRefresh: _loadProducts,
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            _applySearch();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'পণ্যের নাম বা ক্যাটাগরি অনুসন্ধান করুন...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                        ),
                      ),
                    ),

                    // Products Counter Summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'মোট পণ্য: ${_filteredProducts.length}টি',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppTheme.errorRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'কম স্টক চিহ্নিত',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Product List
                    Expanded(
                      child: _filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'কোন পণ্য পাওয়া যায়নি',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () => _openAddProductScreen(productToEdit: product),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          // Product icon with stock indicator
                                          Stack(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: product.isLowStock
                                                      ? AppTheme.errorRed.withValues(alpha: 0.1)
                                                      : AppTheme.primaryGreen.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: product.isLowStock ? AppTheme.errorRed : AppTheme.primaryGreen,
                                                  size: 26,
                                                ),
                                              ),
                                              if (product.isLowStock)
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: const BoxDecoration(
                                                      color: AppTheme.errorRed,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),

                                          // Product Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        product.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (product.isLowStock)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.errorRed,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: const Text(
                                                          'কম স্টক',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'ক্যাটাগরি: ${product.category} (${UnitConversionService.getCategoryLabelBengali(product.unitCategory)})',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      'ক্রয়: ৳${product.buyingPrice.toStringAsFixed(2)}/${product.baseUnit}',
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'বিক্রয়: ৳${product.baseUnitPrice.toStringAsFixed(2)}/${product.baseUnit}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.primaryGreen,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Stock Count & Action
                                          Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: product.isLowStock
                                                      ? AppTheme.errorRed.withValues(alpha: 0.15)
                                                      : AppTheme.accentGold.withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  product.formattedStock,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: product.isLowStock ? AppTheme.errorRed : AppTheme.darkGreen,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () => _showRestockDialog(product),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4.0),
                                                  child: Text(
                                                    '+ স্টক যোগ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.primaryGreen,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
