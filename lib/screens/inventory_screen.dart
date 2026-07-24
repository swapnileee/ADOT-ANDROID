import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _buyingPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
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
      CustomSnackBar.showError(
          context, 'ইনভেন্টরি লোড করতে ব্যর্থ হয়েছে: $e');
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

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final product = ProductModel(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'সাধারণ'
            : _categoryController.text.trim(),
        buyingPrice: double.parse(_buyingPriceController.text.trim()),
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        stockQuantity: int.parse(_stockController.text.trim()),
      );

      await _supabaseService.addProduct(product);

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'পণ্য সফলভাবে সংরক্ষিত হয়েছে!');
      _clearForm();
      Navigator.pop(context); // Close modal
      _loadProducts();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'পণ্য যোগ করতে ত্রুটি হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _categoryController.clear();
    _buyingPriceController.clear();
    _sellingPriceController.clear();
    _stockController.clear();
  }

  void _showAddProductDialog() {
    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'নতুন পণ্য যোগ করুন',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'পণ্যের নাম *',
                      prefixIcon: Icon(Icons.shopping_bag_outlined,
                          color: AppTheme.primaryGreen),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'পণ্যের নাম দিন'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'ক্যাটাগরি (যেমন: মুদি, স্টেশনারি)',
                      prefixIcon: Icon(Icons.category_outlined,
                          color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buyingPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ক্রয় মূল্য (৳) *',
                            prefixIcon: Icon(Icons.move_to_inbox_rounded,
                                color: AppTheme.primaryGreen),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'ক্রয় মূল্য দিন';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'সঠিক সংখ্যা';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'বিক্রয় মূল্য (৳) *',
                            prefixIcon: Icon(Icons.sell_outlined,
                                color: AppTheme.primaryGreen),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'বিক্রয় মূল্য দিন';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'সঠিক সংখ্যা';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'স্টক পরিমাণ (টি) *',
                      prefixIcon: Icon(Icons.inventory_rounded,
                          color: AppTheme.primaryGreen),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'স্টক পরিমাণ দিন';
                      }
                      if (int.tryParse(val.trim()) == null) {
                        return 'সঠিক সংখ্যা';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _addProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      child: _isSubmitting
                          ? const SpinKitThreeBounce(
                              color: Colors.white, size: 20)
                          : const Text('পণ্য প্রস্তুত ও সংরক্ষণ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
            children: [
              Text('বর্তমান স্টক: ${product.stockQuantity}টি'),
              const SizedBox(height: 12),
              TextField(
                controller: restockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'নতুন নতুন যুক্ত স্টক সংখ্যা',
                  suffixText: 'টি',
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
                final added = int.tryParse(restockController.text.trim()) ?? 0;
                if (added <= 0) return;
                final newStock = product.stockQuantity + added;
                Navigator.pop(context);
                try {
                  await _supabaseService.updateProductStock(
                      product.id, newStock);
                  if (!context.mounted) return;
                  CustomSnackBar.showSuccess(
                      context, 'স্টক সফলভাবে আপডেট হয়েছে!');
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
        onPressed: _showAddProductDialog,
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text('নতুন পণ্য',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppTheme.primaryGreen),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark),
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
                              'কম স্টক (<=৫টি)',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
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
                                                  ? AppTheme.errorRed
                                                      .withValues(alpha: 0.1)
                                                  : AppTheme.primaryGreen
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.inventory_2_outlined,
                                              color: product.isLowStock
                                                  ? AppTheme.errorRed
                                                  : AppTheme.primaryGreen,
                                              size: 26,
                                            ),
                                          ),
                                          if (product.isLowStock)
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(3),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    product.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (product.isLowStock)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.errorRed,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: const Text(
                                                      'কম স্টক',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'ক্যাটাগরি: ${product.category}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'ক্রয়: ৳${product.buyingPrice.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.textMuted),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'বিক্রয়: ৳${product.sellingPrice.toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppTheme.primaryGreen,
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: product.isLowStock
                                                  ? AppTheme.errorRed
                                                      .withValues(alpha: 0.15)
                                                  : AppTheme.accentGold
                                                      .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${product.stockQuantity} টি',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: product.isLowStock
                                                    ? AppTheme.errorRed
                                                    : AppTheme.darkGreen,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () =>
                                                _showRestockDialog(product),
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
