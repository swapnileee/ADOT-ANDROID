import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';
import 'product_details_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String _selectedCategoryFilter = 'সকল';
  bool _isLoading = true;

  final List<String> _categoryFilters = [
    'সকল',
    'তেল',
    'শস্য ও ডাল',
    'মধু',
    'ডিম ও দুধ',
    'ফল',
  ];

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
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ইনভেন্টরি লোড করতে ব্যর্থ হয়েছে: $e');
    }
  }

  void _applyFilters() {
    List<Product> temp = List.from(_products);

    if (_selectedCategoryFilter != 'সকল') {
      temp = temp.where((p) => p.category.toLowerCase().contains(_selectedCategoryFilter.toLowerCase())).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      temp = temp.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q) || p.supplier.toLowerCase().contains(q)).toList();
    }

    setState(() {
      _filteredProducts = temp;
    });
  }

  Future<void> _openAddProductScreen({Product? productToEdit}) async {
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

  void _openProductDetails(Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );

    if (result == true) {
      _loadProducts();
    }
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
        title: const Text('পণ্য সমূহ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // Focus search bar
            },
            tooltip: 'খুঁজুন',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddProductScreen(),
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
                color: AppTheme.primaryGreen,
                child: Column(
                  children: [
                    // Search Bar & Filter Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                _searchQuery = val;
                                _applyFilters();
                              },
                              decoration: InputDecoration(
                                hintText: 'পণ্য খুঁজুন...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                                fillColor: Colors.white,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.cardBorderColor),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.tune_rounded, color: Colors.white),
                              onPressed: () {
                                // Toggle category filter
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Horizontally Scrollable Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: _categoryFilters.map((cat) {
                          final isSelected = _selectedCategoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textDark,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorderColor,
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategoryFilter = cat;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Product List Counter Summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'মোট পণ্য: ${_filteredProducts.length}টি',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            'ফিল্টার: $_selectedCategoryFilter',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Product Cards List
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
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () => _openProductDetails(product),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          // Product Thumbnail Image
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              color: AppTheme.lightGreenBg,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: product.imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      product.imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Icon(
                                                        Icons.eco_rounded,
                                                        color: AppTheme.primaryGreen,
                                                        size: 32,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.eco_rounded,
                                                      color: AppTheme.primaryGreen,
                                                      size: 32,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),

                                          // Product Details & Subtitles
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.cleanName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '${product.variants.length} টি ভ্যারিয়েন্ট',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.primaryGreen,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'স্টক: ${product.formattedStock}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: product.isLowStock ? AppTheme.errorRed : AppTheme.textMuted,
                                                        fontWeight: product.isLowStock ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                 const SizedBox(height: 4),
                                                 Row(
                                                   children: [
                                                     Text(
                                                       'কেনা: ৳${product.buyingPrice.toStringAsFixed(0)}',
                                                       style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                     ),
                                                     const SizedBox(width: 6),
                                                     Text(
                                                       'বেচা: ৳${product.sellingPrice.toStringAsFixed(0)}',
                                                       style: const TextStyle(fontSize: 11, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                                                     ),
                                                     const SizedBox(width: 6),
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                       decoration: BoxDecoration(
                                                         color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                                                         borderRadius: BorderRadius.circular(6),
                                                       ),
                                                       child: Text(
                                                         'লাভ: ৳${product.unitProfit.toStringAsFixed(0)}',
                                                         style: const TextStyle(
                                                           fontSize: 11,
                                                           fontWeight: FontWeight.bold,
                                                           color: AppTheme.primaryGreen,
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Price Range Display on Right
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                product.priceRangeText,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: AppTheme.textMuted,
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
