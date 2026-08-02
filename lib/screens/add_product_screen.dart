import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_constants.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import '../services/refresh_signal.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;

  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color primaryDarkGreen = Color(0xFF1E4D3B);
  static const Color bgLightGray = Color(0xFFF8F9FA);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color infoBannerBg = Color(0xFFE8F5E9);

  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _supplierController;
  late TextEditingController _imageUrlController;
  late TextEditingController _minStockController;

  String _selectedCategory = 'নিত্যপণ্য';
  String _selectedBaseUnit = 'Pcs';
  bool _isSubmitting = false;

  List<String> get _categories {
    final list = List<String>.from(AppConstants.productDropdownCategories);
    final pCat = widget.productToEdit?.category;
    if (pCat != null && pCat.isNotEmpty && !list.contains(pCat)) {
      list.insert(0, pCat);
    }
    return list;
  }

  final List<String> _baseUnits = ['Pcs', 'Kg', 'gm', 'Liter', 'ml', 'Pack'];

  // List of dynamic variant row controllers
  final List<Map<String, dynamic>> _variantRows = [];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _supplierController = TextEditingController(text: p?.supplier ?? 'ADOT Organic');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _minStockController = TextEditingController(text: '10');

    if (p != null) {
      _selectedCategory = _categories.contains(p.category) ? p.category : _categories.first;
      _selectedBaseUnit = _baseUnits.contains(p.baseUnit) ? p.baseUnit : _baseUnits.first;

      if (p.variants.isNotEmpty) {
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

    if (_variantRows.isEmpty) {
      _addVariantRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _supplierController.dispose();
    _imageUrlController.dispose();
    _minStockController.dispose();
    for (var row in _variantRows) {
      row['sizeController']?.dispose();
      row['buyingPriceController']?.dispose();
      row['priceController']?.dispose();
      row['stockController']?.dispose();
    }
    super.dispose();
  }

  void _addVariantRow([String? customSize]) {
    setState(() {
      final defaultLabel = customSize ?? (_variantRows.isEmpty ? '250 $_selectedBaseUnit' : '500 $_selectedBaseUnit');
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
      CustomSnackBar.showWarning(context, 'অন্তত একটি ভ্যারিয়েন্ট থাকা আবশ্যক');
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

  List<String> get _quickVariantOptions {
    final unit = _selectedBaseUnit.toLowerCase();
    if (unit == 'liter' || unit == 'ltr' || unit == 'ml') {
      return ['250 ml', '500 ml', '1 Liter', '2 Liter', '5 Liter'];
    } else if (unit == 'kg' || unit == 'gm' || unit == 'g') {
      return ['250 gm', '500 gm', '1 Kg', '2 Kg', '5 Kg'];
    } else {
      return ['১ পিস', '২ পিস', '৪ পিস', '৬ পিস', '১২ পিস'];
    }
  }

  void _addQuickVariant(String label) {
    final exists = _variantRows.any((row) {
      final sizeCtrl = row['sizeController'] as TextEditingController;
      return sizeCtrl.text.trim().toLowerCase() == label.trim().toLowerCase();
    });
    if (exists) {
      CustomSnackBar.showWarning(context, 'ভ্যারিয়েন্ট "$label" ইতোমধ্যে যোগ করা হয়েছে');
      return;
    }
    _addVariantRow(label);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_variantRows.isEmpty) {
      CustomSnackBar.showWarning(context, 'অনুগ্রহ করে অন্তত একটি ভ্যারিয়েন্ট যোগ করুন');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final List<ProductVariant> variants = [];

      for (var row in _variantRows) {
        final size = (row['sizeController'] as TextEditingController).text.trim();
        final price = double.tryParse((row['priceController'] as TextEditingController).text.trim()) ?? 0.0;
        final stock = double.tryParse((row['stockController'] as TextEditingController).text.trim()) ?? 0.0;

        variants.add(ProductVariant(
          id: row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          sizeLabel: size.isEmpty ? '১টি' : size,
          price: price,
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

      RefreshSignal().notifyDataChanged();
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
      backgroundColor: bgLightGray,
      appBar: AppBar(
        backgroundColor: primaryDarkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'পণ্য সংশোধন / এডিট' : 'নতুন পণ্য যোগ করুন',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductInfoCard(),
                      const SizedBox(height: 16),
                      _buildVariantsTableCard(),
                      const SizedBox(height: 16),
                      _buildMinStockCard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildBottomSaveButton(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: primaryDarkGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'পণ্যের বিবরণ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Product Name Input
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'পণ্যের নাম *',
                hintText: 'পণ্যের নাম লিখুন',
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: primaryDarkGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'পণ্যের নাম লিখুন' : null,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                // Category Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'ক্যাটাগরি *',
                      prefixIcon: const Icon(Icons.category_outlined, color: primaryDarkGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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

                // Unit Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBaseUnit,
                    decoration: InputDecoration(
                      labelText: 'ইউনিট *',
                      prefixIcon: const Icon(Icons.square_foot_outlined, color: primaryDarkGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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

            const SizedBox(height: 12),

            // Info Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBannerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: primaryDarkGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ইউনিট নির্বাচন করার পর ভ্যারিয়েন্ট যোগ করুন',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'যেমন: 250ml, 500ml, 1L বা 250gm, 500gm, 1kg',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantsTableCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'ভ্যারিয়েন্ট (সাইজ/ওজন/ধারণক্ষমতা)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                  ),
                ),
                InkWell(
                  onTap: () => _addVariantRow(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: primaryDarkGreen),
                        SizedBox(width: 4),
                        Text(
                          'ভ্যারিয়েন্ট যোগ করুন',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryDarkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Table Column Titles Header
            Row(
              children: [
                const SizedBox(width: 22), // space for drag handle
                Expanded(
                  flex: 3,
                  child: Text(
                    'সাইজ/ওজন',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ক্রয় মূল্য (৳)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'বিক্রয় মূল্য (৳)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'স্টক',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 28), // space for delete icon
              ],
            ),

            const SizedBox(height: 8),

            // Variant Item Rows
            ..._variantRows.asMap().entries.map((entry) {
              return _buildVariantRowItem(entry.key, entry.value);
            }),

            const SizedBox(height: 14),

            // Quick Variant Chips Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgLightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: primaryDarkGreen),
                      SizedBox(width: 6),
                      Text(
                        'দ্রুত ভ্যারিয়েন্ট যোগ করুন',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _quickVariantOptions.map((opt) {
                      return ActionChip(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: cardBorderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        label: Text(
                          opt,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryDarkGreen),
                        ),
                        onPressed: () => _addQuickVariant(opt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantRowItem(int index, Map<String, dynamic> row) {
    final sizeCtrl = row['sizeController'] as TextEditingController;
    final buyingPriceCtrl = row['buyingPriceController'] as TextEditingController;
    final priceCtrl = row['priceController'] as TextEditingController;
    final stockCtrl = row['stockController'] as TextEditingController;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: sizeCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '250 ml',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'সাইজ' : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: buyingPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '75',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'ক্রয়';
                if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                return null;
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '100',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'বিক্রয়';
                if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                return null;
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: stockCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '50',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'স্টক';
                if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                return null;
              },
            ),
          ),
          SizedBox(
            width: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
              onPressed: () => _removeVariantRow(index),
              tooltip: 'মুছুন',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinStockCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: primaryDarkGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'ন্যূনতম স্টক (ঐচ্ছিক)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minStockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'ন্যূনতম স্টক লিখুন',
                hintText: '১০',
                prefixIcon: const Icon(Icons.inventory_outlined, color: primaryDarkGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryDarkGreen, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'স্টক এই পরিমাণের নিচে নামলে সতর্কতা দেখাবে।',
              style: TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveButton(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: cardBorderColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryDarkGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: _isSubmitting
              ? const SizedBox.shrink()
              : const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
          label: _isSubmitting
              ? const SpinKitThreeBounce(color: Colors.white, size: 22)
              : Text(
                  isEditing ? 'পণ্য সংশোধন আপডেট করুন' : 'পণ্য সংরক্ষণ করুন',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      ),
    );
  }
}
