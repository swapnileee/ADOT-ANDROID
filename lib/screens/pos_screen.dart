import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_constants.dart';
import '../services/supabase_service.dart';
import '../services/refresh_signal.dart';
import '../models/product_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';

class PosCartItem {
  final Product product;
  final ProductVariant variant;
  int quantity;
  double totalPrice;

  PosCartItem({
    required this.product,
    required this.variant,
    required this.quantity,
    required this.totalPrice,
  });

  String get displayTitle => '${product.cleanName} (${variant.sizeLabel})';
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => POSScreenState();
}

class POSScreenState extends State<POSScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _checkoutFormKey = GlobalKey<FormState>();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String _selectedCategoryFilter = 'সকল';
  bool _hideOutOfStock = false;
  String _selectedPaymentMethod = 'নগদ';

  final List<PosCartItem> _cartItems = [];
  double _paidAmount = 0.0;

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  bool _isLoadingProducts = true;
  bool _isSubmitting = false;

  final List<String> _categories = AppConstants.defaultCategories;

  final List<String> _paymentMethods = [
    'নগদ',
    'বিকাশ',
    'ব্যাংক',
    'বকেয়া',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
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
      temp = temp
          .where((p) => p.category
              .toLowerCase()
              .contains(_selectedCategoryFilter.toLowerCase()))
          .toList();
    }

    if (_hideOutOfStock) {
      temp = temp.where((p) => p.totalStock > 0).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      temp = temp
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }

    setState(() {
      _filteredProducts = temp;
    });
  }

  void _showPosCategoryFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final Set<String> allCategories = {
              'সকল',
              ..._categories,
              ..._products.map((p) => p.category.trim()).where((c) => c.isNotEmpty)
            };

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ক্যাটাগরি ফিল্টার করুন',
                            style: TextStyle(
                              fontSize: 18,
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
                      const Divider(),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: allCategories.map((category) {
                          final isSelected = _selectedCategoryFilter == category;
                          return ChoiceChip(
                            label: Text(category),
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
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategoryFilter = category;
                                  _applySearch();
                                });
                                Navigator.pop(context);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double get _cartTotal {
    double total = 0.0;
    for (var item in _cartItems) {
      total += item.totalPrice;
    }
    return total;
  }

  int get _cartTotalItemCount {
    int count = 0;
    for (var item in _cartItems) {
      count += item.quantity;
    }
    return count;
  }

  int _getProductCartQuantity(Product product) {
    int total = 0;
    for (var item in _cartItems) {
      if (item.product.id == product.id) {
        total += item.quantity;
      }
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
        (i) =>
            i.product.id == cartItem.product.id &&
            i.variant.id == cartItem.variant.id,
      );
      if (index >= 0) {
        _cartItems[index].quantity += cartItem.quantity;
        _cartItems[index].totalPrice =
            _cartItems[index].quantity * _cartItems[index].variant.price;
      } else {
        _cartItems.add(cartItem);
      }
      _syncPaidAmount();
    });
  }

  void _quickAddDefaultVariant(Product product) {
    if (product.totalStock <= 0) {
      CustomSnackBar.showWarning(context, 'পণ্যটির স্টক শেষ!');
      return;
    }
    if (product.variants.length > 1) {
      _openPosVariantModal(product);
      return;
    }

    final variant = product.variants.first;
    final cartItem = PosCartItem(
      product: product,
      variant: variant,
      quantity: 1,
      totalPrice: variant.price,
    );
    _addToCart(cartItem);
  }

  void _quickDecrementProduct(Product product) {
    setState(() {
      final index = _cartItems.indexWhere((i) => i.product.id == product.id);
      if (index >= 0) {
        if (_cartItems[index].quantity > 1) {
          _cartItems[index].quantity--;
          _cartItems[index].totalPrice =
              _cartItems[index].quantity * _cartItems[index].variant.price;
        } else {
          _cartItems.removeAt(index);
        }
        _syncPaidAmount();
      }
    });
  }

  void _updateCartItemQuantity(int index, int delta) {
    setState(() {
      final currentItem = _cartItems[index];
      final newQty = currentItem.quantity + delta;
      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        if (newQty > currentItem.variant.stock) {
          CustomSnackBar.showWarning(
              context, 'স্টক লিমিটের বেশি যোগ করা যাবে না');
          return;
        }
        currentItem.quantity = newQty;
        currentItem.totalPrice = newQty * currentItem.variant.price;
      }
      _syncPaidAmount();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _syncPaidAmount();
    });
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.errorRed, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorRed),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void refreshData() {
    _loadProducts();
  }

  Future<void> _submitCheckout() async {
    if (_cartItems.isEmpty) {
      CustomSnackBar.showWarning(
          context, 'অনুগ্রহ করে কার্টে অন্তত একটি পণ্য যোগ করুন');
      return;
    }

    if (!_checkoutFormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final customerName = _customerNameController.text.trim().isEmpty
          ? 'নগদ ক্রেতা'
          : _customerNameController.text.trim();
      final customerPhone = _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim();

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
        customerPhone: customerPhone,
        paidAmount: _paidAmount,
        totalCartPrice: _cartTotal,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'বিক্রি সফলভাবে সম্পন্ন হয়েছে!');
      Navigator.pop(context); // Close bottom sheet if open
      _resetCartAndForm();
      _loadProducts(); // Refresh stocks
      RefreshSignal().notifyDataChanged(); // Notify all screens (Dashboard, Orders, Inventory, Expenses)
    } on PostgrestException catch (e) {
      if (!mounted) return;
      debugPrint(
          'SUPABASE POSTGREST ERROR: ${e.message} | Details: ${e.details} | Code: ${e.code}');
      _showErrorDialog(
        context,
        'Supabase Postgrest Error (${e.code})',
        'Message: ${e.message}\n\nDetails: ${e.details ?? "None"}\nHint: ${e.hint ?? "None"}',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('GENERIC CHECKOUT ERROR: $e');
      _showErrorDialog(context, 'Checkout Error', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetCartAndForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _paidAmountController.clear();
    setState(() {
      _cartItems.clear();
      _paidAmount = 0.0;
    });
  }

  void _showLongPressOptionsSheet(Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.cleanName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen),
              ),
              Text(
                'ক্যাটেগরি: ${product.category} • স্টক: ${product.formattedStock}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.primaryGreen),
                title: const Text('পণ্য বিবরণী (View Details)'),
                onTap: () {
                  Navigator.pop(context);
                  _showProductDetailsDialog(product);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                title: const Text('পণ্য এডিট (Edit Product)'),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AddProductScreen(productToEdit: product)),
                  );
                  if (res == true) _loadProducts();
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined,
                    color: AppTheme.warningOrange),
                title: const Text('স্টক আপডেট (Update Stock)'),
                onTap: () {
                  Navigator.pop(context);
                  _showQuickUpdateStockDialog(product);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorRed),
                title: const Text('পণ্য মুছুন (Delete Product)',
                    style: TextStyle(color: AppTheme.errorRed)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteProduct(product);
                },
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  void _showProductDetailsDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.cleanName,
            style: const TextStyle(color: AppTheme.primaryGreen)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ক্যাটেগরি: ${product.category}'),
            Text('সরবরাহকারী: ${product.supplier}'),
            Text('মোট স্টক: ${product.formattedStock}'),
            Text('মূল্য পরিসর: ${product.priceRangeText}'),
            const SizedBox(height: 10),
            const Text('ভ্যারিয়েন্টসমূহ:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...product.variants.map((v) => Text(
                '• ${v.sizeLabel}: ৳${v.price.toStringAsFixed(0)} (স্টক: ${v.stock.toInt()})')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বন্ধ করুন')),
        ],
      ),
    );
  }

  void _showQuickUpdateStockDialog(Product product) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${product.cleanName} - স্টক আপডেট'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'নতুন যোগ করার পরিমাণ (Base Unit)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim()) ?? 0;
              if (val > 0) {
                await _supabaseService.updateProductStock(product.id, val);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                _loadProducts();
              }
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পণ্য মুছে ফেলা নিশ্চিত করুন'),
        content: Text('আপনি কি সত্যিই "${product.cleanName}" ডিলিট করতে চান?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              CustomSnackBar.showSuccess(context, 'পণ্য মুছে ফেলা হয়েছে');
              _loadProducts();
            },
            child:
                const Text('মুছুন', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
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

  /// Opens Material 3 Sticky Cart & Checkout Bottom Sheet Modal
  void _openCartCheckoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _checkoutFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row (FIXED TOP)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_cart_rounded,
                                    color: AppTheme.primaryGreen),
                                const SizedBox(width: 8),
                                const Text(
                                  'বিক্রি কার্ট ও চেকআউট',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_cartTotalItemCountটি',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        const Divider(height: 12),

                        // Cart Items List (INDEPENDENTLY SCROLLABLE MIDDLE CONTAINER)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 180,
                          ),
                          child: _cartItems.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'কার্ট খালি রয়েছে',
                                      style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _cartItems[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.displayTitle,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'একক মূল্য: ৳${item.variant.price.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Quantity Adjuster Controls (-) counter (+)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: AppTheme.lightGreenBg,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      _updateCartItemQuantity(
                                                          index, -1);
                                                      setModalState(() {});
                                                    },
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(6.0),
                                                      child: Icon(Icons.remove,
                                                          size: 16,
                                                          color: AppTheme
                                                              .errorRed),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8.0),
                                                    child: Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      _updateCartItemQuantity(
                                                          index, 1);
                                                      setModalState(() {});
                                                    },
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(6.0),
                                                      child: Icon(Icons.add,
                                                          size: 16,
                                                          color: AppTheme
                                                              .primaryGreen),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '৳${item.totalPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppTheme.primaryGreen),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AppTheme.errorRed,
                                                  size: 20),
                                              onPressed: () {
                                                _removeFromCart(index);
                                                setModalState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        const SizedBox(height: 10),

                        // Checkout Inputs Container with Payment Method Selection (FIXED BOTTOM)
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('সর্বমোট মূল্য:',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      '৳ ${_cartTotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),

                                // Payment Method Selection Chips
                                const Text(
                                  'পেমেন্ট মাধ্যম (Payment Method):',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: _paymentMethods.map((method) {
                                    final isSelected =
                                        _selectedPaymentMethod == method;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 6.0),
                                      child: ChoiceChip(
                                        label: Text(method),
                                        selected: isSelected,
                                        selectedColor: AppTheme.primaryGreen,
                                        backgroundColor: AppTheme.creamBg,
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : AppTheme.textDark,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                        onSelected: (val) {
                                          if (val) {
                                            setModalState(() {
                                              _selectedPaymentMethod = method;
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _customerNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'ক্রেতার নাম (ঐচ্ছিক)',
                                    prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                        color: AppTheme.primaryGreen),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _customerPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'ক্রেতার মোবাইল নম্বর (ঐচ্ছিক)',
                                    prefixIcon: Icon(Icons.phone_rounded,
                                        color: AppTheme.primaryGreen),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _paidAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'জমা/পরিশোধিত টাকা (৳)',
                                    prefixIcon: Icon(Icons.payments_outlined,
                                        color: AppTheme.primaryGreen),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _paidAmount = double.tryParse(val) ?? 0.0;
                                    });
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _dueAmount > 0
                                        ? const Color(0xFFFEF3C7)
                                        : AppTheme.lightGreenBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _dueAmount > 0
                                            ? 'বকেয়া পরিমাণ:'
                                            : 'পরিশোধের অবস্থা:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _dueAmount > 0
                                              ? AppTheme.warningOrange
                                              : AppTheme.primaryGreen,
                                        ),
                                      ),
                                      Text(
                                        _dueAmount > 0
                                            ? '৳ ${_dueAmount.toStringAsFixed(0)}'
                                            : 'সম্পূর্ণ পরিশোধিত',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _dueAmount > 0
                                              ? AppTheme.warningOrange
                                              : AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Submit Checkout Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting || _cartItems.isEmpty
                                ? null
                                : _submitCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox.shrink()
                                : const Icon(Icons.check_circle_rounded,
                                    color: Colors.white),
                            label: _isSubmitting
                                ? const SpinKitThreeBounce(
                                    color: Colors.white, size: 22)
                                : const Text(
                                    'বিক্রি নিশ্চিত করুন ও ইনভয়েস জমা দিন',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Sticky Floating Bottom Cart Bar
  Widget _buildFloatingCartBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _openCartCheckoutBottomSheet,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_cart_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🛒 $_cartTotalItemCount টি পণ্য',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'মোট: ৳ ${_cartTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _openCartCheckoutBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'কার্ট ও চেকআউট',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryGreen),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppTheme.primaryGreen),
                ],
              ),
            ),
          ],
        ),
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
      bottomNavigationBar: _cartItems.isNotEmpty
          ? SafeArea(child: _buildFloatingCartBar())
          : null,
      body: SafeArea(
        child: _isLoadingProducts
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildProductGridSection(),
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
          // Search Bar & Category Filter Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    _searchQuery = val;
                    _applySearch();
                  },
                  decoration: const InputDecoration(
                    hintText: 'পণ্যের নাম বা ক্যাটেগরি দিয়ে খুঁজুন...',
                    prefixIcon:
                        Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                    fillColor: Colors.white,
                    filled: true,
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
                  onPressed: () => _showPosCategoryFilterBottomSheet(context),
                  tooltip: 'ক্যাটাগরি ফিল্টার',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Category Chips & Hide Out of Stock Toggle
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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

          const SizedBox(height: 8),

          // Checkbox Toggle: Hide Out of Stock Products
          Row(
            children: [
              Checkbox(
                value: _hideOutOfStock,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) {
                  setState(() {
                    _hideOutOfStock = val ?? false;
                    _applySearch();
                  });
                },
              ),
              const Text(
                'স্টক শেষ পণ্য লুকান (Hide Out of Stock)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Product List Cards with Clean Display Names, Circular Add Button, Stock Status, and Inline Quantity Controls
          _filteredProducts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                      child: Text('কোন পণ্য পাওয়া যায়নি',
                          style: TextStyle(color: AppTheme.textMuted))),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final cartQty = _getProductCartQuantity(product);
                    final isOutOfStock = product.totalStock <= 0;

                    // Stock status indicator dot and label
                    Widget stockStatusBadge;
                    if (isOutOfStock) {
                      stockStatusBadge = const Row(
                        children: [
                          Icon(Icons.circle,
                              color: AppTheme.errorRed, size: 10),
                          SizedBox(width: 4),
                          Text('স্টক শেষ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.bold)),
                        ],
                      );
                    } else if (product.totalStock <= 5) {
                      stockStatusBadge = Row(
                        children: [
                          const Icon(Icons.circle,
                              color: AppTheme.warningOrange, size: 10),
                          const SizedBox(width: 4),
                          Text('কম স্টক (${product.totalStock.toInt()}টি)',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.bold)),
                        ],
                      );
                    } else {
                      stockStatusBadge = Row(
                        children: [
                          const Icon(Icons.circle,
                              color: AppTheme.primaryGreen, size: 10),
                          const SizedBox(width: 4),
                          Text('ইন স্টক (${product.totalStock.toInt()}টি)',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600)),
                        ],
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onLongPress: () => _showLongPressOptionsSheet(product),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Product Image Container
                              Container(
                                width: 50,
                                height: 50,
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
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.eco_rounded,
                                                  color: AppTheme.primaryGreen),
                                        )
                                      : const Icon(Icons.eco_rounded,
                                          color: AppTheme.primaryGreen),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Product Info Column (Name, Price, Stock Status ONLY)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.cleanName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      product.priceRangeText,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    stockStatusBadge,
                                  ],
                                ),
                              ),

                              // Right Action Widget: Circular Add (+) button or Inline Quantity Picker [-] X [+]
                              if (isOutOfStock)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('অপ্রাপ্য',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.errorRed,
                                          fontWeight: FontWeight.bold)),
                                )
                              else if (cartQty == 0)
                                InkWell(
                                  onTap: () => _quickAddDefaultVariant(product),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add,
                                        color: Colors.white, size: 22),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreenBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppTheme.primaryGreen
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            _quickDecrementProduct(product),
                                        borderRadius: BorderRadius.circular(14),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.remove,
                                              size: 18,
                                              color: AppTheme.errorRed),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Text(
                                          '$cartQty',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.primaryGreen),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            _quickAddDefaultVariant(product),
                                        borderRadius: BorderRadius.circular(14),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.add,
                                              size: 18,
                                              color: AppTheme.primaryGreen),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
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
  State<_PosVariantSelectionModal> createState() =>
      _PosVariantSelectionModalState();
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
    return SafeArea(
      top: false,
      child: Padding(
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

          // Product Info Row with Clean Name
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
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: AppTheme.primaryGreen),
                        )
                      : const Icon(Icons.eco_rounded,
                          color: AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.cleanName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'মোট স্টক: ${widget.product.formattedStock}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
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
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.cardBorderColor,
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
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '৳ ${v.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white70
                                    : AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
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
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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
              border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_counterQuantity × ${_selectedVariant.sizeLabel}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '৳${_selectedVariant.price.toStringAsFixed(0)} প্রতি এককে',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('মোট দাম',
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      '৳ ${_calculatedTotalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen),
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
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'পর্যাপ্ত স্টক নেই! (অবশিষ্ট স্টক: ${_selectedVariant.stock.toInt()}টি)',
                      style: const TextStyle(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('বাতিল',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('কার্টে যোগ করুন',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
