import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_snackbar.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isNewProductMode = false;

  // Existing Product Mode Controllers
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();

  // New Product Mode Controllers
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newCategoryController =
      TextEditingController(text: 'নিত্যপণ্য');
  final TextEditingController _newSellingPriceController =
      TextEditingController();
  String _newBaseUnit = 'pcs';

  List<Product> _products = [];
  List<PurchaseModel> _purchases = [];
  Product? _selectedProduct;
  ProductVariant? _selectedVariant;

  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<String> _categoryOptions = [
    'নিত্যপণ্য',
    'তেল',
    'মধু',
    'মসলা',
    'চাল ও ডাল',
    'ঘি ও মাখন',
    'প্রসাধন',
    'অন্যান্য',
  ];

  final List<String> _unitOptions = ['pcs', 'kg', 'g', 'ml', 'L'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _qtyController.addListener(_updateTotalCostPreview);
    _priceController.addListener(_updateTotalCostPreview);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _historySearchController.dispose();
    _newNameController.dispose();
    _newCategoryController.dispose();
    _newSellingPriceController.dispose();
    super.dispose();
  }

  void _updateTotalCostPreview() {
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _supabaseService.fetchProducts();
      final purchases = await _supabaseService.fetchPurchases();

      if (!mounted) return;
      setState(() {
        _products = products;
        _purchases = purchases;
        _isLoading = false;

        if (_products.isNotEmpty && _selectedProduct == null) {
          _onSelectProduct(_products.first);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ডাটা লোড করতে সমস্যা হয়েছে: $e');
    }
  }

  void _onSelectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _selectedVariant =
          product.variants.isNotEmpty ? product.variants.first : null;
      _supplierController.text = product.supplier;
      _priceController.text =
          _selectedVariant != null && _selectedVariant!.price > 0
              ? (_selectedVariant!.price * 0.75).toStringAsFixed(0)
              : '0';
    });
  }

  void _showProductSelectionModal() {
    final searchController = TextEditingController();
    List<Product> filteredProducts = List.from(_products);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'পণ্য নির্বাচন করুন',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'পণ্যের নাম খুঁজুন...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.primaryGreen),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        filteredProducts = _products
                            .where((p) => p.name
                                .toLowerCase()
                                .contains(query.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? const Center(
                            child: Text('কোন পণ্য পাওয়া যায়নি',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: filteredProducts.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = filteredProducts[index];
                              final isSelected = _selectedProduct?.id == p.id;
                              return ListTile(
                                tileColor: isSelected
                                    ? AppTheme.primaryGreen
                                        .withValues(alpha: 0.08)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryGreen
                                      .withValues(alpha: 0.1),
                                  child: Text(
                                    p.cleanName.substring(0, 1),
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(p.cleanName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'ক্যাটাগরি: ${p.category} | বর্তমান স্টক: ${p.formattedStock}'),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: AppTheme.primaryGreen)
                                    : const Icon(Icons.chevron_right_rounded,
                                        color: Colors.grey),
                                onTap: () {
                                  _onSelectProduct(p);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitStockIn() async {
    if (!_formKey.currentState!.validate()) return;

    final double qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final double buyingPrice =
        double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (qty <= 0) {
      CustomSnackBar.showError(context, 'অনুগ্রহ করে সঠিক পরিমাণ লিখুন!');
      return;
    }
    if (buyingPrice < 0) {
      CustomSnackBar.showError(context, 'অনুগ্রহ করে সঠিক ক্রয় মূল্য লিখুন!');
      return;
    }

    if (_isNewProductMode) {
      final String newName = _newNameController.text.trim();
      final String category = _newCategoryController.text.trim();
      final double sellingPrice =
          double.tryParse(_newSellingPriceController.text.trim()) ?? 0.0;

      if (newName.isEmpty) {
        CustomSnackBar.showError(context, 'অনুগ্রহ করে নতুন পণ্যের নাম লিখুন!');
        return;
      }
      if (sellingPrice <= 0) {
        CustomSnackBar.showError(
            context, 'অনুগ্রহ করে সঠিক বিক্রয় মূল্য (MRP) লিখুন!');
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final productId = 'p_${DateTime.now().millisecondsSinceEpoch}';
        final variantId = 'v_${DateTime.now().millisecondsSinceEpoch}';

        final newVariant = ProductVariant(
          id: variantId,
          sizeLabel: '1 $_newBaseUnit',
          price: sellingPrice,
          stock: qty,
        );

        final newProduct = Product(
          id: productId,
          name: newName,
          category: category.isNotEmpty ? category : 'নিত্যপণ্য',
          supplier: _supplierController.text.trim().isNotEmpty
              ? _supplierController.text.trim()
              : 'ADOT Supplier',
          imageUrl:
              'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
          baseUnit: _newBaseUnit,
          variants: [newVariant],
        );

        await _supabaseService.addProduct(newProduct);

        final purchase = PurchaseModel(
          productId: productId,
          productName: newName,
          variantId: variantId,
          variantLabel: newVariant.sizeLabel,
          quantityAdded: qty,
          buyingPrice: buyingPrice,
          supplierName: newProduct.supplier,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : 'নতুন পণ্য ক্রয় ও প্রাথমিক স্টক',
          createdAt: DateTime.now(),
        );

        await _supabaseService.processStockIn(purchase: purchase);

        if (!mounted) return;
        CustomSnackBar.showSuccess(
            context, 'নতুন পণ্য সফলভাবে স্টকে যুক্ত হয়েছে!');

        _newNameController.clear();
        _newSellingPriceController.clear();
        _qtyController.clear();
        _priceController.clear();
        _notesController.clear();
        _isNewProductMode = false;
        _loadData();
      } catch (e) {
        if (!mounted) return;
        CustomSnackBar.showError(
            context, 'নতুন পণ্য যোগ করতে সমস্যা হয়েছে: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      if (_selectedProduct == null) {
        CustomSnackBar.showError(
            context, 'অনুগ্রহ করে একটি পণ্য নির্বাচন করুন!');
        return;
      }
      if (_selectedProduct!.variants.isNotEmpty && _selectedVariant == null) {
        CustomSnackBar.showError(
            context, 'অনুগ্রহ করে একটি ভ্যারিয়েন্ট নির্বাচন করুন!');
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final purchase = PurchaseModel(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.cleanName,
          variantId: _selectedVariant?.id,
          variantLabel: _selectedVariant?.sizeLabel,
          quantityAdded: qty,
          buyingPrice: buyingPrice,
          supplierName: _supplierController.text.trim().isNotEmpty
              ? _supplierController.text.trim()
              : _selectedProduct!.supplier,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          createdAt: DateTime.now(),
        );

        await _supabaseService.processStockIn(purchase: purchase);

        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'স্টক ইন সফলভাবে সম্পন্ন হয়েছে!');

        _qtyController.clear();
        _notesController.clear();
        _loadData();
      } catch (e) {
        if (!mounted) return;
        CustomSnackBar.showError(context, 'স্টক ইন করতে সমস্যা হয়েছে: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  double get _calculatedTotalCost {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return qty * price;
  }

  List<PurchaseModel> get _filteredPurchases {
    final query = _historySearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _purchases;
    return _purchases.where((p) {
      final pName = p.productName.toLowerCase();
      final supp = (p.supplierName ?? '').toLowerCase();
      final notes = (p.notes ?? '').toLowerCase();
      return pName.contains(query) ||
          supp.contains(query) ||
          notes.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'ক্রয় / স্টক ইন',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.add_box_rounded), text: 'নতুন স্টক ইন'),
              Tab(icon: Icon(Icons.history_rounded), text: 'ক্রয় ইতিহাস'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child:
                    SpinKitFadingCube(color: AppTheme.primaryGreen, size: 40.0))
            : TabBarView(
                children: [
                  _buildNewStockInTab(),
                  _buildPurchaseHistoryTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isNewProductMode = false),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isNewProductMode
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: !_isNewProductMode
                          ? Colors.white
                          : AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'বিদ্যমান পণ্য',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: !_isNewProductMode
                            ? Colors.white
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isNewProductMode = true),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isNewProductMode
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_box_rounded,
                      size: 18,
                      color: _isNewProductMode
                          ? Colors.white
                          : AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'নতুন পণ্য যোগ করুন',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isNewProductMode
                            ? Colors.white
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: NEW STOCK IN FORM (DUAL MODE)
  Widget _buildNewStockInTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DUAL MODE SWITCHER BAR
            _buildModeSwitcher(),

            if (!_isNewProductMode) ...[
              // EXISTING PRODUCT SELECTOR CARD
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: AppTheme.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'পণ্য নির্বাচন করুন',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showProductSelectionModal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.primaryGreen
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                            color:
                                AppTheme.primaryGreen.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  color: AppTheme.primaryGreen),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedProduct != null
                                          ? _selectedProduct!.cleanName
                                          : 'পণ্য বাছাই করুন',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _selectedProduct != null
                                            ? AppTheme.textDark
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (_selectedProduct != null)
                                      Text(
                                        'ক্যাটাগরি: ${_selectedProduct!.category} | স্টক: ${_selectedProduct!.formattedStock}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_circle_outlined,
                                  color: AppTheme.primaryGreen),
                            ],
                          ),
                        ),
                      ),

                      // VARIANT SELECTION (IF PRODUCT HAS VARIANTS)
                      if (_selectedProduct != null &&
                          _selectedProduct!.variants.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'ভ্যারিয়েন্ট (প্যাক সাইজ)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedProduct!.variants.map((v) {
                            final isSelected = _selectedVariant?.id == v.id;
                            return ChoiceChip(
                              label: Text(
                                  '${v.sizeLabel} (স্টক: ${v.stock.toStringAsFixed(0)})'),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryGreen,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedVariant = v;
                                    if (v.price > 0) {
                                      _priceController.text =
                                          (v.price * 0.75).toStringAsFixed(0);
                                    }
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // NEW PRODUCT CREATION CARD
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_box_outlined,
                              color: AppTheme.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'নতুন পণ্যের বিবরণ',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Product Name
                      TextFormField(
                        controller: _newNameController,
                        decoration: InputDecoration(
                          labelText: 'পণ্যের নাম *',
                          hintText: 'যেমন: লাক্স সাবান 100g',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined,
                              color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (_isNewProductMode &&
                              (val == null || val.trim().isEmpty)) {
                            return 'পণ্যের নাম লিখুন';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          // Category Dropdown/Text
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _categoryOptions
                                      .contains(_newCategoryController.text)
                                  ? _newCategoryController.text
                                  : _categoryOptions.first,
                              decoration: InputDecoration(
                                labelText: 'ক্যাটাগরি *',
                                prefixIcon: const Icon(Icons.category_outlined,
                                    color: AppTheme.primaryGreen),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _categoryOptions.map((cat) {
                                return DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat,
                                        style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(
                                      () => _newCategoryController.text = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Base Unit Dropdown
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _newBaseUnit,
                              decoration: InputDecoration(
                                labelText: 'একক *',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _unitOptions.map((u) {
                                return DropdownMenuItem(
                                    value: u,
                                    child: Text(u,
                                        style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _newBaseUnit = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Selling Price (MRP)
                      TextFormField(
                        controller: _newSellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'বিক্রয় মূল্য / MRP (৳) *',
                          hintText: 'যেমন: 50',
                          prefixText: '৳ ',
                          prefixIcon: const Icon(Icons.sell_outlined,
                              color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (_isNewProductMode) {
                            if (val == null || val.trim().isEmpty) {
                              return 'বিক্রয় মূল্য লিখুন';
                            }
                            if (double.tryParse(val.trim()) == null) {
                              return 'সঠিক সংখ্যা দিন';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // QUANTITY & BUYING PRICE INPUT CARD
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_list_numbered_rounded,
                            color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'পরিমাণ ও ক্রয় তথ্য',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Quantity
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'যোগকৃত পরিমাণ *',
                              hintText: 'যেমন: 10',
                              suffixText: _isNewProductMode
                                  ? _newBaseUnit
                                  : (_selectedProduct?.baseUnit ?? ''),
                              prefixIcon: const Icon(Icons.add_shopping_cart,
                                  color: AppTheme.primaryGreen, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'পরিমাণ দিন';
                              }
                              if (double.tryParse(val.trim()) == null) {
                                return 'সঠিক সংখ্যা দিন';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Price Per Unit
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'একক ক্রয় মূল্য (৳) *',
                              hintText: 'যেমন: 250',
                              prefixText: '৳ ',
                              prefixIcon: const Icon(Icons.payments_outlined,
                                  color: AppTheme.primaryGreen, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'মূল্য দিন';
                              }
                              if (double.tryParse(val.trim()) == null) {
                                return 'সঠিক সংখ্যা দিন';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // LIVE TOTAL COST PREVIEW
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.primaryGreen.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'সর্বমোট ক্রয় খরচ:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textDark),
                          ),
                          Text(
                            '৳ ${_calculatedTotalCost.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // VENDOR & NOTES CARD
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'সরবরাহকারী ও চালান নোট (ঐচ্ছিক)',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _supplierController,
                      decoration: InputDecoration(
                        labelText: 'সরবরাহকারী / ভেন্ডর নাম',
                        hintText: 'যেমন: ADOT Organic Farm / Unilever',
                        prefixIcon: const Icon(Icons.business_outlined,
                            color: AppTheme.primaryGreen, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'নোট / চালান / মেমো রেফারেন্স',
                        hintText: 'যেমন: মেমো #৪৫২',
                        prefixIcon: const Icon(Icons.notes_rounded,
                            color: AppTheme.primaryGreen, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitStockIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_rounded,
                        color: Colors.white),
                label: _isSubmitting
                    ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                    : Text(
                        _isNewProductMode
                            ? 'নতুন পণ্য স্টকে যুক্ত করুন'
                            : 'স্টক ইন সম্পন্ন করুন',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // TAB 2: PURCHASE HISTORY LIST
  Widget _buildPurchaseHistoryTab() {
    final filtered = _filteredPurchases;

    return Column(
      children: [
        // SEARCH FILTER BAR
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: TextField(
            controller: _historySearchController,
            decoration: InputDecoration(
              hintText: 'ক্রয় ইতিহাস খুঁজুন (পণ্যের নাম, সরবরাহকারী)...',
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.primaryGreen),
              filled: true,
              fillColor: AppTheme.creamBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded,
                          size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'কোন ক্রয় ইতিহাস পাওয়া যায়নি',
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final dateStr = item.createdAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(item.createdAt!)
                        : 'তারিখ নেই';

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      if (item.variantLabel != null &&
                                          item.variantLabel!.isNotEmpty)
                                        Text(
                                          'ভ্যারিয়েন্ট: ${item.variantLabel}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${item.quantityAdded} টি/পরিমাণ',
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'একক দর: ৳ ${item.buyingPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                                Text(
                                  'মোট খরচ: ৳ ${item.totalCost.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (item.supplierName != null &&
                                item.supplierName!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.business_outlined,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'সরবরাহকারী: ${item.supplierName}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'নোট: ${item.notes}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                dateStr,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
