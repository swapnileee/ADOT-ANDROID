import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/unit_conversion_service.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class PosCartItem {
  final ProductModel product;
  final double inputQuantity;
  final String selectedUnit;
  final double baseQuantity;
  final double totalPrice;

  PosCartItem({
    required this.product,
    required this.inputQuantity,
    required this.selectedUnit,
    required this.baseQuantity,
    required this.totalPrice,
  });

  String get displayQuantityWithUnit => UnitConversionService.formatQuantityWithUnit(inputQuantity, selectedUnit);
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _checkoutFormKey = GlobalKey<FormState>();

  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _searchQuery = '';

  final List<PosCartItem> _cartItems = [];

  double _paidAmount = 0.0;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

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
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
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
      // Check if product already exists in cart, update it
      final index = _cartItems.indexWhere((i) => i.product.id == cartItem.product.id);
      if (index >= 0) {
        _cartItems[index] = cartItem;
      } else {
        _cartItems.add(cartItem);
      }
      _syncPaidAmount();
    });
    CustomSnackBar.showSuccess(context, '${cartItem.product.name} কার্ডে যোগ করা হয়েছে!');
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
      final customerName = _customerNameController.text.trim().isEmpty
          ? 'নগদ ক্রেতা'
          : _customerNameController.text.trim();

      final List<Map<String, dynamic>> cartPayload = _cartItems.map((item) {
        return {
          'product': item.product,
          'baseQuantity': item.baseQuantity,
          'displayQtyWithUnit': item.displayQuantityWithUnit,
          'totalPrice': item.totalPrice,
        };
      }).toList();

      await _supabaseService.processCartCheckout(
        cartItems: cartPayload,
        customerName: customerName,
        paidAmount: _paidAmount,
        totalCartPrice: _cartTotal,
      );

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'বিক্রি সফলভাবে সম্পন্ন হয়েছে!');
      _resetCartAndForm();
      _loadProducts(); // Reload stock after sale
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'বিক্রি প্রক্রিয়া করতে ত্রুটি: $e');
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

  /// Opens the modern Material 3 Smart POS Quantity Selector Bottom Sheet
  void _openQuantitySelectorBottomSheet(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PosQuantitySelectorBottomSheet(
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
        title: const Text('স্মার্ট পয়েন্ট অব সেল (POS)'),
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
            : _products.isEmpty
                ? _buildEmptyProductsView()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth > 700;
                      if (isTablet) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildProductSelectorSection()),
                            const VerticalDivider(width: 1),
                            Expanded(flex: 2, child: _buildCartAndCheckoutSection()),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildProductSelectorSection(),
                            const Divider(height: 24, thickness: 2),
                            _buildCartAndCheckoutSection(),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyProductsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'কোন পণ্য পাওয়া যায়নি!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'বিক্রি করার জন্য ইনভেন্টরি স্ক্রীন থেকে পণ্য যোগ করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('পুনরায় চেষ্টা করুন'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelectorSection() {
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
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applySearch();
              });
            },
            decoration: const InputDecoration(
              hintText: 'পণ্যের নাম বা ক্যাটাগরি খুঁজুন...',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 12),
          _filteredProducts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('কোন পণ্য পাওয়া যায়নি', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final bool isLow = product.isLowStock;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _openQuantitySelectorBottomSheet(product),
                        leading: CircleAvatar(
                          backgroundColor: isLow
                              ? AppTheme.errorRed.withValues(alpha: 0.1)
                              : AppTheme.primaryGreen.withValues(alpha: 0.1),
                          child: Icon(
                            product.unitCategory == UnitCategory.weight
                                ? Icons.scale_outlined
                                : product.unitCategory == UnitCategory.volume
                                    ? Icons.water_drop_outlined
                                    : Icons.widgets_outlined,
                            color: isLow ? AppTheme.errorRed : AppTheme.primaryGreen,
                          ),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'ক্যাটাগরি: ${product.category} | স্টক: ${product.formattedStock}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLow ? AppTheme.errorRed : AppTheme.textMuted,
                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '৳${product.baseUnitPrice.toStringAsFixed(2)}/${product.baseUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                            ),
                            const Text(
                              '+ কার্টে যোগ',
                              style: TextStyle(fontSize: 11, color: AppTheme.accentGold, fontWeight: FontWeight.bold),
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

  Widget _buildCartAndCheckoutSection() {
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
                    label: const Text('সব মুছুন', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Cart Items List
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
                            'উপরে পণ্য ট্যাপ করে পরিমাণ নির্বাচন করুন।',
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
                          title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'পরিমাণ: ${item.displayQuantityWithUnit}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '৳${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
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

            // Cart Summary Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '৩. পরিশোধের বিবরণ',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('সর্বমোট কার্ট মূল্য:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                        hintText: 'যেমন: রফিকুল ইসলাম',
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _dueAmount > 0 ? const Color(0xFFFEF7E0) : const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dueAmount > 0 ? 'বকেয়া/বাকি পরিমাণ:' : 'পরিশোধের অবস্থা:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _dueAmount > 0 ? AppTheme.warningOrange : AppTheme.primaryGreen,
                            ),
                          ),
                          Text(
                            _dueAmount > 0 ? '৳ ${_dueAmount.toStringAsFixed(0)}' : 'সম্পূর্ণ পরিশোধিত',
                            style: TextStyle(
                              fontSize: 16,
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
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _cartItems.isEmpty ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                label: _isSubmitting
                    ? const SpinKitThreeBounce(color: Colors.white, size: 24)
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

/// Material 3 Bottom Sheet for Quantity & Unit Selection (Requirements 3-8)
class _PosQuantitySelectorBottomSheet extends StatefulWidget {
  final ProductModel product;
  final Function(PosCartItem) onAddToCart;

  const _PosQuantitySelectorBottomSheet({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_PosQuantitySelectorBottomSheet> createState() => _PosQuantitySelectorBottomSheetState();
}

class _PosQuantitySelectorBottomSheetState extends State<_PosQuantitySelectorBottomSheet> {
  final _qtyFormKey = GlobalKey<FormState>();
  late TextEditingController _quantityInputController;

  late String _selectedUnit;
  late double _inputQuantity;

  @override
  void initState() {
    super.initState();
    final availableUnits = UnitConversionService.getAvailableUnits(widget.product.unitCategory);
    _selectedUnit = availableUnits.first;
    _inputQuantity = 1.0;
    _quantityInputController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityInputController.dispose();
    super.dispose();
  }

  double get _calculatedBaseQuantity {
    return UnitConversionService.toBaseQuantity(_inputQuantity, _selectedUnit, widget.product.unitCategory);
  }

  double get _calculatedTotalPrice {
    return UnitConversionService.calculateTotalPrice(_calculatedBaseQuantity, widget.product.baseUnitPrice);
  }

  bool get _isStockInsufficient {
    return _calculatedBaseQuantity > widget.product.stockInBaseUnit;
  }

  void _applyQuickQuantity(double value, String unit) {
    setState(() {
      _selectedUnit = unit;
      _inputQuantity = value;
      _quantityInputController.text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.product.unitCategory;
    final availableUnits = UnitConversionService.getAvailableUnits(category);
    final quickOptions = UnitConversionService.getQuickQuantityOptions(category);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _qtyFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Product Name & Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ক্যাটাগরি: ${widget.product.category} | বেস একক: ${widget.product.baseUnit}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.product.isLowStock
                          ? AppTheme.errorRed.withValues(alpha: 0.15)
                          : AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('অবশিষ্ট স্টক', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        Text(
                          widget.product.formattedStock,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.product.isLowStock ? AppTheme.errorRed : AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Choose Quantity Heading
              const Text(
                'Choose Quantity (পরিমাণ নির্বাচন করুন)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 10),

              // Quick Buttons Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickOptions.map((opt) {
                  final String label = opt['label'];
                  final double val = opt['value'];
                  final String unit = opt['unit'];
                  final bool isSelected = (_inputQuantity == val && _selectedUnit == unit);

                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (bool selected) {
                      if (selected) {
                        _applyQuickQuantity(val, unit);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Unit Selector Segmented Buttons / Toggle & Custom Quantity Input
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Toggle Dropdown / Buttons
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'একক (Unit)',
                        prefixIcon: Icon(Icons.tune_rounded, color: AppTheme.primaryGreen),
                      ),
                      items: availableUnits.map((u) {
                        return DropdownMenuItem<String>(
                          value: u,
                          child: Text(u, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUnit = val;
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Custom Quantity Input
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityInputController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: widget.product.allowDecimal,
                      ),
                      decoration: InputDecoration(
                        labelText: 'পরিমাণ (Custom Qty) *',
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen),
                        errorStyle: const TextStyle(fontSize: 11),
                        enabledBorder: _isStockInsufficient
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _inputQuantity = double.tryParse(val.trim()) ?? 0.0;
                        });
                      },
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'পরিমাণ দিন';
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) return '০-এর বেশি দিন';
                        if (!widget.product.allowDecimal && parsed != parsed.roundToDouble()) {
                          return 'শুধুমাত্র পূর্ণসংখ্যা';
                        }
                        if (_isStockInsufficient) {
                          return 'স্টকের চেয়ে বেশি';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Live Price Calculation Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'হিসেব: ${UnitConversionService.formatQuantityWithUnit(_inputQuantity, _selectedUnit)} = ${_calculatedBaseQuantity.toInt()} ${widget.product.baseUnit}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        Text(
                          '৳${widget.product.baseUnitPrice}/${widget.product.baseUnit}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('মোট দাম (Total Price):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '৳ ${_calculatedTotalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stock Validation Error Banner (Requirement 8)
              if (_isStockInsufficient) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE8E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'পর্যাপ্ত স্টক নেই! (Insufficient Stock)\nপ্রয়োজন: ${_calculatedBaseQuantity.toInt()} ${widget.product.baseUnit} | অবশিষ্ট: ${widget.product.formattedStock}',
                          style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons: Cancel & Add to Cart
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('বাতিল', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isStockInsufficient || _inputQuantity <= 0)
                          ? null
                          : () {
                              if (!_qtyFormKey.currentState!.validate()) return;
                              final cartItem = PosCartItem(
                                product: widget.product,
                                inputQuantity: _inputQuantity,
                                selectedUnit: _selectedUnit,
                                baseQuantity: _calculatedBaseQuantity,
                                totalPrice: _calculatedTotalPrice,
                              );
                              widget.onAddToCart(cartItem);
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                      label: const Text('কার্টে যোগ করুন', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
