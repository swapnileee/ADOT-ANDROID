import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class PosCartItem {
  final Product product;
  final ProductVariant variant;
  final int quantity;
  final double totalPrice;

  PosCartItem({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.totalPrice,
  });

  String get displayTitle => '${product.name} (${variant.sizeLabel})';
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _checkoutFormKey = GlobalKey<FormState>();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String _selectedCategoryFilter = 'সকল';

  final List<PosCartItem> _cartItems = [];
  double _paidAmount = 0.0;

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  final List<String> _categories = [
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

  @override
  void dispose() {
    _customerNameController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await _supabaseService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _applySearch();
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
      CustomSnackBar.showError(context, 'পণ্য লোড করতে ব্যর্থ হয়েছে: $e');
    }
  }

  void _applySearch() {
    List<Product> temp = List.from(_products);

    if (_selectedCategoryFilter != 'সকল') {
      temp = temp.where((p) => p.category.toLowerCase().contains(_selectedCategoryFilter.toLowerCase())).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      temp = temp.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
    }

    setState(() {
      _filteredProducts = temp;
    });
  }

  double get _cartTotal {
    double total = 0.0;
    for (var item in _cartItems) {
      total += item.totalPrice;
    }
    return total;
  }

  double get _dueAmount {
    final due = _cartTotal - _paidAmount;
    return due > 0 ? due : 0.0;
  }

  void _syncPaidAmount() {
    setState(() {
      _paidAmount = _cartTotal;
      _paidAmountController.text = _cartTotal.toStringAsFixed(0);
    });
  }

  void _addToCart(PosCartItem cartItem) {
    setState(() {
      final index = _cartItems.indexWhere(
        (i) => i.product.id == cartItem.product.id && i.variant.id == cartItem.variant.id,
      );
      if (index >= 0) {
        _cartItems[index] = cartItem;
      } else {
        _cartItems.add(cartItem);
      }
      _syncPaidAmount();
    });
    CustomSnackBar.showSuccess(context, '${cartItem.displayTitle} কার্টে যোগ করা হয়েছে!');
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _syncPaidAmount();
    });
  }

  Future<void> _submitCheckout() async {
    if (_cartItems.isEmpty) {
      CustomSnackBar.showWarning(context, 'অনুগ্রহ করে কার্টে অন্তত একটি পণ্য যোগ করুন');
      return;
    }

    if (!_checkoutFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final customerName = _customerNameController.text.trim().isEmpty ? 'নগদ ক্রেতা' : _customerNameController.text.trim();

      final List<Map<String, dynamic>> payload = _cartItems.map((item) {
        return {
          'product': item.product,
          'variant': item.variant,
          'itemQuantity': item.quantity,
          'totalPrice': item.totalPrice,
        };
      }).toList();

      await _supabaseService.processCartCheckout(
        cartItems: payload,
        customerName: customerName,
        paidAmount: _paidAmount,
        totalCartPrice: _cartTotal,
      );

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'বিক্রি সফলভাবে সম্পন্ন হয়েছে!');
      _resetCartAndForm();
      _loadProducts(); // Refresh stocks
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'বিক্রি করতে ত্রুটি: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetCartAndForm() {
    _customerNameController.clear();
    _paidAmountController.clear();
    setState(() {
      _cartItems.clear();
      _paidAmount = 0.0;
    });
  }

  /// Opens Screen 4: POS Variant Selection Modal
  void _openPosVariantModal(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PosVariantSelectionModal(
        product: product,
        onAddToCart: _addToCart,
      ),
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
        title: const Text('POS - পয়েন্ট অব সেল'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingProducts
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth > 750;
                  if (isTablet) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildProductGridSection()),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 2, child: _buildCartSection()),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildProductGridSection(),
                        const Divider(height: 24, thickness: 2),
                        _buildCartSection(),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProductGridSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '১. পণ্য নির্বাচন করুন (ট্যাপ করুন)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 10),

          // Search Bar
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applySearch();
            },
            decoration: const InputDecoration(
              hintText: 'পণ্যের নাম দিয়ে খুঁজুন...',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
              fillColor: Colors.white,
              filled: true,
            ),
          ),

          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGreen,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategoryFilter = cat;
                          _applySearch();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Product List / Cards
          _filteredProducts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('কোন পণ্য পাওয়া যায়নি', style: TextStyle(color: AppTheme.textMuted))),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _openPosVariantModal(product),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                                  )
                                : const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                          ),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${product.variants.length}টি ভ্যারিয়েন্ট | স্টক: ${product.formattedStock}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              product.priceRangeText,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 14),
                            ),
                            const Text(
                              '+ ভ্যারিয়েন্ট বাছুন',
                              style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _checkoutFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '২. বিক্রি কার্ট (Cart Summary)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                ),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _cartItems.clear()),
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                    label: const Text('মুছুন', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            _cartItems.isEmpty
                ? Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: const Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 40, color: AppTheme.textMuted),
                          SizedBox(height: 8),
                          Text('কার্ট খালি রয়েছে', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'উপরে পণ্য ট্যাপ করে ভ্যারিয়েন্ট ও পরিমাণ নির্বাচন করুন।',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text(item.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'পরিমাণ: ${item.quantity}টি × ৳${item.variant.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '৳ ${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed, size: 20),
                                onPressed: () => _removeFromCart(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 16),

            // Checkout Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('সর্বমোট মূল্য:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          '৳ ${_cartTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'ক্রেতার নাম (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'জমা/পরিশোধিত টাকা (৳)',
                        prefixIcon: Icon(Icons.payments_outlined, color: AppTheme.primaryGreen),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _paidAmount = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _dueAmount > 0 ? const Color(0xFFFEF3C7) : AppTheme.lightGreenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dueAmount > 0 ? 'বকেয়া পরিমাণ:' : 'পরিশোধের অবস্থা:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _dueAmount > 0 ? AppTheme.warningOrange : AppTheme.primaryGreen,
                            ),
                          ),
                          Text(
                            _dueAmount > 0 ? '৳ ${_dueAmount.toStringAsFixed(0)}' : 'সম্পূর্ণ পরিশোধিত',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _dueAmount > 0 ? AppTheme.warningOrange : AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _cartItems.isEmpty ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: _isSubmitting
                    ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                    : const Text(
                        'বিক্রি নিশ্চিত করুন ও ইনভয়েস জমা দিন',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 4: POS Variant Selection Modal Widget (POS - ভ্যারিয়েন্ট নির্বাচন)
class _PosVariantSelectionModal extends StatefulWidget {
  final Product product;
  final Function(PosCartItem) onAddToCart;

  const _PosVariantSelectionModal({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_PosVariantSelectionModal> createState() => _PosVariantSelectionModalState();
}

class _PosVariantSelectionModalState extends State<_PosVariantSelectionModal> {
  late ProductVariant _selectedVariant;
  int _counterQuantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.variants.first;
  }

  double get _calculatedTotalPrice {
    return _selectedVariant.price * _counterQuantity;
  }

  bool get _isStockInsufficient {
    return _counterQuantity > _selectedVariant.stock;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'POS - ভ্যারিয়েন্ট নির্বাচন',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const Divider(height: 16),

          // Product Info Row
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: widget.product.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                        )
                      : const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'মোট স্টক: ${widget.product.formattedStock}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dynamic Variant Grid Selector Cards
          const Text(
            'ভ্যারিয়েন্ট বাছাই করুন:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),

          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.product.variants.length,
            itemBuilder: (context, index) {
              final v = widget.product.variants[index];
              final isSelected = v.id == _selectedVariant.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedVariant = v;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBorderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              v.sizeLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '৳ ${v.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white70 : AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Quantity Adjuster (-) Counter (+)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'পরিমাণ (Quantity):',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.cardBorderColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppTheme.errorRed),
                      onPressed: _counterQuantity > 1
                          ? () => setState(() => _counterQuantity--)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        '$_counterQuantity',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
                      onPressed: () => setState(() => _counterQuantity++),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Selection Breakdown Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_counterQuantity × ${_selectedVariant.sizeLabel}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '৳${_selectedVariant.price.toStringAsFixed(0)} প্রতি এককে',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('মোট দাম', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      '৳ ${_calculatedTotalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isStockInsufficient) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'পর্যাপ্ত স্টক নেই! (অবশিষ্ট স্টক: ${_selectedVariant.stock.toInt()}টি)',
                      style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons: "বাতিল" (Cancel) & "কার্টে যোগ করুন" (Add to Cart)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('বাতিল', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isStockInsufficient
                      ? null
                      : () {
                          final item = PosCartItem(
                            product: widget.product,
                            variant: _selectedVariant,
                            quantity: _counterQuantity,
                            totalPrice: _calculatedTotalPrice,
                          );
                          widget.onAddToCart(item);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                  label: const Text('কার্টে যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
