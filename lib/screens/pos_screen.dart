import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  List<ProductModel> _products = [];
  ProductModel? _selectedProduct;
  
  int _quantity = 1;
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
        if (_products.isNotEmpty) {
          _selectedProduct = _products.first;
          _recalculateTotal();
        }
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
      CustomSnackBar.showError(context, 'পণ্য লোড করতে ব্যর্থ হয়েছে: $e');
    }
  }

  double get _totalPrice {
    if (_selectedProduct == null) return 0.0;
    return _selectedProduct!.sellingPrice * _quantity;
  }

  double get _dueAmount {
    final due = _totalPrice - _paidAmount;
    return due > 0 ? due : 0.0;
  }

  void _recalculateTotal() {
    setState(() {
      _paidAmount = _totalPrice;
      _paidAmountController.text = _totalPrice.toStringAsFixed(0);
    });
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      CustomSnackBar.showWarning(context, 'অনুগ্রহ করে একটি পণ্য নির্বাচন করুন');
      return;
    }

    if (_selectedProduct!.stockQuantity < _quantity) {
      CustomSnackBar.showError(
        context,
        'পর্যাপ্ত স্টক নেই! ${_selectedProduct!.name}-এর অবশিষ্ট স্টক: ${_selectedProduct!.stockQuantity}টি',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final sale = SaleModel(
        productName: _selectedProduct!.name,
        quantity: _quantity,
        totalPrice: _totalPrice,
        customerName: _customerNameController.text.trim().isEmpty
            ? 'নগদ ক্রেতা'
            : _customerNameController.text.trim(),
        paidAmount: _paidAmount,
        dueAmount: _dueAmount,
      );

      await _supabaseService.processSale(
        sale: sale,
        productId: _selectedProduct!.id,
        currentStock: _selectedProduct!.stockQuantity,
      );

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'বিক্রি সফলভাবে সম্পন্ন হয়েছে!');
      _resetForm();
      _loadProducts(); // Reload stock
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'বিক্রি প্রক্রিয়া করতে ত্রুটি: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _customerNameController.clear();
    setState(() {
      _quantity = 1;
      _paidAmount = 0.0;
      _paidAmountController.clear();
    });
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
        title: const Text('পয়েন্ট অব সেল (POS) / নতুন বিক্রি'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'পণ্য তালিকা রিফ্রেশ',
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
              ? Center(
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
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Selector Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '১. পণ্য নির্বাচন করুন',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ProductModel>(
                                  initialValue: _selectedProduct,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'পণ্য নির্বাচন',
                                    prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen),
                                  ),
                                  selectedItemBuilder: (BuildContext context) {
                                    return _products.map((ProductModel p) {
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${p.name} (৳${p.sellingPrice.toStringAsFixed(0)} | স্টক: ${p.stockQuantity})',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                  items: _products.map((ProductModel p) {
                                    return DropdownMenuItem<ProductModel>(
                                      value: p,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${p.name} (৳${p.sellingPrice.toStringAsFixed(0)} | স্টক: ${p.stockQuantity})',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (ProductModel? newProduct) {
                                    setState(() {
                                      _selectedProduct = newProduct;
                                      _recalculateTotal();
                                    });
                                  },
                                ),
                                if (_selectedProduct != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedProduct!.isLowStock
                                          ? const Color(0xFFFCE8E6)
                                          : const Color(0xFFE6F4EA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _selectedProduct!.isLowStock
                                              ? Icons.warning_amber_rounded
                                              : Icons.check_circle_outline,
                                          color: _selectedProduct!.isLowStock
                                              ? AppTheme.errorRed
                                              : AppTheme.primaryGreen,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ক্যাটাগরি: ${_selectedProduct!.category} | অবশিষ্ট স্টক: ${_selectedProduct!.stockQuantity}টি',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _selectedProduct!.isLowStock
                                                  ? AppTheme.errorRed
                                                  : AppTheme.primaryGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Quantity & Pricing Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '২. পরিমাণ ও হিসেব',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'পণ্যের পরিমাণ:',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, color: AppTheme.errorRed),
                                            onPressed: _quantity > 1
                                                ? () {
                                                    setState(() {
                                                      _quantity--;
                                                      _recalculateTotal();
                                                    });
                                                  }
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: Text(
                                              '$_quantity',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
                                            onPressed: () {
                                              setState(() {
                                                _quantity++;
                                                _recalculateTotal();
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'মোট মূল্য:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '৳ ${_totalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Payment & Customer Info Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '৩. ক্রেতা ও পরিশোধের বিবরণ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                                  keyboardType: TextInputType.number,
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
                                    color: _dueAmount > 0
                                        ? const Color(0xFFFEF7E0)
                                        : const Color(0xFFE6F4EA),
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

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitSale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox.shrink()
                                : const Icon(Icons.check_circle_rounded, size: 22),
                            label: _isSubmitting
                                ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                                : const Text(
                                    'বিক্রি নিশ্চিত করুন ও ইনভয়েস জমা দিন',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
