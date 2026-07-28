import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;

  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  bool _hasMultipleVariants = false;

  late TextEditingController _nameController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _initialStockController;
  late TextEditingController _supplierController;
  late TextEditingController _imageUrlController;

  String _selectedCategory = 'সাধারণ';
  String _selectedBaseUnit = 'Pcs';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'নিত্যপণ্য',
    'তেল',
    'শস্য ও ডাল',
    'মধু',
    'ডিম ও দুধ',
    'ফল',
    'প্রসাধন',
    'সাধারণ',
  ];

  final List<String> _baseUnits = ['Pcs', 'Kg', 'Gm', 'Ltr', 'ml', 'Pack'];

  // List of dynamic variant row controllers
  final List<Map<String, dynamic>> _variantRows = [];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _supplierController = TextEditingController(text: p?.supplier ?? 'ADOT Organic');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');

    double defaultSellingPrice = 0.0;
    double defaultBuyingPrice = 0.0;
    double defaultStock = 0.0;

    if (p != null) {
      _selectedCategory = _categories.contains(p.category) ? p.category : _categories.first;
      _selectedBaseUnit = _baseUnits.contains(p.baseUnit) ? p.baseUnit : _baseUnits.first;

      if (p.variants.length > 1) {
        _hasMultipleVariants = true;
      }

      if (p.variants.isNotEmpty) {
        final firstV = p.variants.first;
        defaultSellingPrice = firstV.price;
        defaultBuyingPrice = firstV.price > 0 ? (firstV.price * 0.75) : 0.0;
        defaultStock = p.totalStock;

        for (var v in p.variants) {
          final bPrice = v.price > 0 ? (v.price * 0.75).toStringAsFixed(0) : '0';
          _variantRows.add({
            'id': v.id,
            'sizeController': TextEditingController(text: v.sizeLabel),
            'buyingPriceController': TextEditingController(text: bPrice),
            'priceController': TextEditingController(text: v.price.toStringAsFixed(0)),
            'stockController': TextEditingController(
                text: v.stock == v.stock.roundToDouble() ? v.stock.toInt().toString() : v.stock.toString()),
          });
        }
      }
    }

    _buyingPriceController = TextEditingController(
        text: defaultBuyingPrice > 0 ? defaultBuyingPrice.toStringAsFixed(0) : '');
    _sellingPriceController = TextEditingController(
        text: defaultSellingPrice > 0 ? defaultSellingPrice.toStringAsFixed(0) : '');
    _initialStockController = TextEditingController(
        text: defaultStock > 0
            ? (defaultStock == defaultStock.roundToDouble() ? defaultStock.toInt().toString() : defaultStock.toString())
            : '10');

    if (_variantRows.isEmpty) {
      _addVariantRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _initialStockController.dispose();
    _supplierController.dispose();
    _imageUrlController.dispose();
    for (var row in _variantRows) {
      row['sizeController']?.dispose();
      row['buyingPriceController']?.dispose();
      row['priceController']?.dispose();
      row['stockController']?.dispose();
    }
    super.dispose();
  }

  void _addVariantRow() {
    setState(() {
      final defaultLabel = _variantRows.isEmpty ? '250 $_selectedBaseUnit' : '500 $_selectedBaseUnit';
      _variantRows.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sizeController': TextEditingController(text: defaultLabel),
        'buyingPriceController': TextEditingController(text: '75'),
        'priceController': TextEditingController(text: '100'),
        'stockController': TextEditingController(text: '50'),
      });
    });
  }

  void _removeVariantRow(int index) {
    if (_variantRows.length <= 1) {
      CustomSnackBar.showWarning(context, 'অন্তত একটি ভ্যারিয়েন্ট থাকা আবশ্যক');
      return;
    }
    setState(() {
      final row = _variantRows.removeAt(index);
      row['sizeController']?.dispose();
      row['buyingPriceController']?.dispose();
      row['priceController']?.dispose();
      row['stockController']?.dispose();
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final List<ProductVariant> variants = [];

      if (_hasMultipleVariants) {
        if (_variantRows.isEmpty) {
          CustomSnackBar.showWarning(context, 'অনুগ্রহ করে অন্তত একটি ভ্যারিয়েন্ট যোগ করুন');
          setState(() => _isSubmitting = false);
          return;
        }

        for (var row in _variantRows) {
          final size = (row['sizeController'] as TextEditingController).text.trim();
          final price = double.parse((row['priceController'] as TextEditingController).text.trim());
          final stock = double.parse((row['stockController'] as TextEditingController).text.trim());

          variants.add(ProductVariant(
            id: row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            sizeLabel: size.isEmpty ? '১টি' : size,
            price: price,
            stock: stock,
          ));
        }
      } else {
        final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
        final stock = double.tryParse(_initialStockController.text.trim()) ?? 0.0;

        variants.add(ProductVariant(
          id: widget.productToEdit?.variants.firstOrNull?.id ?? 'v_${DateTime.now().millisecondsSinceEpoch}',
          sizeLabel: '1 $_selectedBaseUnit',
          price: sellingPrice,
          stock: stock,
        ));
      }

      final product = Product(
        id: widget.productToEdit?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        category: _selectedCategory,
        supplier: _supplierController.text.trim().isEmpty ? 'ADOT Organic' : _supplierController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        baseUnit: _selectedBaseUnit,
        variants: variants,
      );

      if (widget.productToEdit != null) {
        await _supabaseService.updateProduct(product);
        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'পণ্য সফলভাবে আপডেট করা হয়েছে!');
      } else {
        await _supabaseService.addProduct(product);
        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'নতুন পণ্য সফলভাবে সংরক্ষিত হয়েছে!');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'সংরক্ষণে ত্রুটি: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: Text(isEditing ? 'পণ্য সংশোধন / এডিট' : 'নতুন পণ্য যোগ করুন'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MAIN DIRECT FORM CARD
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'পণ্যের বিবরণ',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Product Name Input
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'পণ্যের নাম *',
                            hintText: 'যেমন: সরিষার তেল / লাক্স সাবান 100g',
                            prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'পণ্যের নাম লিখুন' : null,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            // Category Dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'ক্যাটাগরি *',
                                  prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.primaryGreen),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _categories.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Base Unit Dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBaseUnit,
                                decoration: InputDecoration(
                                  labelText: 'ইউনিট *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _baseUnits.map((u) {
                                  return DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedBaseUnit = val);
                                },
                              ),
                            ),
                          ],
                        ),

                        if (!_hasMultipleVariants) ...[
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              // Buying Price
                              Expanded(
                                child: TextFormField(
                                  controller: _buyingPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'ক্রয় মূল্য (৳) *',
                                    prefixText: '৳ ',
                                    prefixIcon: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primaryGreen),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (val) {
                                    if (!_hasMultipleVariants) {
                                      if (val == null || val.trim().isEmpty) return 'ক্রয় মূল্য লিখুন';
                                      if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা দিন';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Selling Price
                              Expanded(
                                child: TextFormField(
                                  controller: _sellingPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'বিক্রয় মূল্য (৳) *',
                                    prefixText: '৳ ',
                                    prefixIcon: const Icon(Icons.sell_outlined, color: AppTheme.primaryGreen),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (val) {
                                    if (!_hasMultipleVariants) {
                                      if (val == null || val.trim().isEmpty) return 'বিক্রয় মূল্য লিখুন';
                                      if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা দিন';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Initial Stock
                          TextFormField(
                            controller: _initialStockController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'প্রাথমিক স্টক পরিমাণ *',
                              suffixText: _selectedBaseUnit,
                              prefixIcon: const Icon(Icons.add_shopping_cart, color: AppTheme.primaryGreen),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (!_hasMultipleVariants) {
                                if (val == null || val.trim().isEmpty) return 'প্রাথমিক স্টক লিখুন';
                                if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা দিন';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Image Link
                        TextFormField(
                          controller: _imageUrlController,
                          decoration: InputDecoration(
                            labelText: 'ছবি URL (ঐচ্ছিক)',
                            prefixIcon: const Icon(Icons.image_outlined, color: AppTheme.primaryGreen),
                            hintText: 'https://images.unsplash.com/...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // MULTIPLE VARIANTS OPT-IN TOGGLE SWITCH
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: SwitchListTile(
                    activeThumbColor: AppTheme.primaryGreen,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: const Text(
                      'একাধিক প্যাক সাইজ বা ভ্যারিয়েন্ট আছে?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                    ),
                    subtitle: const Text(
                      'যেমন: ২৫০মি.লি., ৫০০মি.লি. ও ১লিটার আলাদা প্যাক',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: _hasMultipleVariants,
                    onChanged: (val) => setState(() => _hasMultipleVariants = val),
                  ),
                ),

                // EXPANDABLE VARIANT SECTION (SHOWN ONLY IF SWITCH IS ON)
                if (_hasMultipleVariants) ...[
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ভ্যারিয়েন্ট সমূহ (Variants List)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                      Text(
                        'মোট: ${_variantRows.length}টি',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  ..._variantRows.asMap().entries.map((entry) {
                    return _buildVariantCard(entry.key, entry.value);
                  }),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _addVariantRow,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryGreen),
                      label: const Text(
                        '+ নতুন ভ্যারিয়েন্ট যোগ করুন',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // MAIN ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: _isSubmitting
                        ? const SpinKitThreeBounce(color: Colors.white, size: 22)
                        : Text(
                            isEditing ? 'পণ্য সংশোধন আপডেট করুন' : 'পণ্য সংরক্ষণ করুন',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(int index, Map<String, dynamic> row) {
    final sizeCtrl = row['sizeController'] as TextEditingController;
    final buyingPriceCtrl = row['buyingPriceController'] as TextEditingController;
    final priceCtrl = row['priceController'] as TextEditingController;
    final stockCtrl = row['stockController'] as TextEditingController;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ভ্যারিয়েন্ট #${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                  onPressed: () => _removeVariantRow(index),
                  tooltip: 'ভ্যারিয়েন্ট মুছুন',
                ),
              ],
            ),
            const Divider(height: 16),

            // Row 1: Label & Buying Price
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: sizeCtrl,
                    decoration: InputDecoration(
                      labelText: 'ভ্যারিয়েন্ট নাম / সাইজ *',
                      hintText: 'যেমন: ২৫০ মি.লি. / ১ কেজি',
                      prefixIcon: const Icon(Icons.straighten_rounded, color: AppTheme.primaryGreen, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    validator: (v) => _hasMultipleVariants && (v == null || v.trim().isEmpty) ? 'সাইজ লিখুন' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: buyingPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'ক্রয় মূল্য (৳) *',
                      prefixText: '৳ ',
                      prefixIcon: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primaryGreen, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    validator: (v) {
                      if (_hasMultipleVariants) {
                        if (v == null || v.trim().isEmpty) return 'ক্রয় মূল্য';
                        if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Selling Price & Stock
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'বিক্রয় মূল্য (৳) *',
                      prefixText: '৳ ',
                      prefixIcon: const Icon(Icons.sell_outlined, color: AppTheme.primaryGreen, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    validator: (v) {
                      if (_hasMultipleVariants) {
                        if (v == null || v.trim().isEmpty) return 'বিক্রয় মূল্য';
                        if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: stockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'স্টক পরিমাণ *',
                      suffixText: _selectedBaseUnit,
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    validator: (v) {
                      if (_hasMultipleVariants) {
                        if (v == null || v.trim().isEmpty) return 'স্টক দিন';
                        if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                      }
                      return null;
                    },
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
