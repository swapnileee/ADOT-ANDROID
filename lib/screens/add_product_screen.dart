import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';
import '../services/unit_conversion_service.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? productToEdit;

  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _baseUnitPriceController;
  late TextEditingController _openingStockController;

  UnitCategory _selectedCategory = UnitCategory.count;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _buyingPriceController = TextEditingController(text: p != null ? p.buyingPrice.toStringAsFixed(2) : '');
    _baseUnitPriceController = TextEditingController(text: p != null ? p.baseUnitPrice.toStringAsFixed(2) : '');
    _openingStockController = TextEditingController(
      text: p != null ? (p.stockInBaseUnit == p.stockInBaseUnit.roundToDouble() ? p.stockInBaseUnit.toInt().toString() : p.stockInBaseUnit.toString()) : '',
    );
    _selectedCategory = p?.unitCategory ?? UnitCategory.count;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _buyingPriceController.dispose();
    _baseUnitPriceController.dispose();
    _openingStockController.dispose();
    super.dispose();
  }

  String get _currentBaseUnitLabel => UnitConversionService.getBaseUnitLabel(_selectedCategory);

  String get _liveStockHelperText {
    final stockVal = double.tryParse(_openingStockController.text.trim()) ?? 0.0;
    return UnitConversionService.formatOpeningStockHelper(stockVal, _selectedCategory);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final double buyingPrice = double.parse(_buyingPriceController.text.trim());
      final double baseUnitPrice = double.parse(_baseUnitPriceController.text.trim());
      final double stockInBaseUnit = double.parse(_openingStockController.text.trim());

      final product = ProductModel(
        id: widget.productToEdit?.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? 'সাধারণ' : _categoryController.text.trim(),
        buyingPrice: buyingPrice,
        unitCategory: _selectedCategory,
        baseUnit: UnitConversionService.getBaseUnit(_selectedCategory),
        baseUnitPrice: baseUnitPrice,
        stockInBaseUnit: stockInBaseUnit,
        allowDecimal: _selectedCategory != UnitCategory.count,
      );

      if (widget.productToEdit != null) {
        await _supabaseService.updateProduct(product);
        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'পণ্য আপডেট সফল হয়েছে!');
      } else {
        await _supabaseService.addProduct(product);
        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'নতুন পণ্য সফলভাবে যোগ করা হয়েছে!');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'সংরক্ষণে ত্রুটি হয়েছে: $e');
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Basic Info Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'সাধারণ তথ্য (Basic Info)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'পণ্যের নাম *',
                            prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen),
                            hintText: 'যেমন: আখের লাল চিনি / সরিষার তেল',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'পণ্যের নাম দিন' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'ক্যাটাগরি (যেমন: মুদি, পানীয়, মশলা)',
                            prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primaryGreen),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _buyingPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'ক্রয় মূল্য (প্রতি বেস ইউনিট ৳) *',
                            prefixIcon: Icon(Icons.move_to_inbox_rounded, color: AppTheme.primaryGreen),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'ক্রয় মূল্য দিন';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'সঠিক মূল্য দিন (০-এর বেশি)';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Unit & Inventory Section (Requirement 2)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unit & Inventory (একক ও স্টক)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Unit Category Dropdown
                        DropdownButtonFormField<UnitCategory>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Unit Category (এককের ধরন) *',
                            prefixIcon: Icon(Icons.scale_outlined, color: AppTheme.primaryGreen),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: UnitCategory.weight,
                              child: Text('Weight (ওজন - Gram/Kg)'),
                            ),
                            DropdownMenuItem(
                              value: UnitCategory.volume,
                              child: Text('Volume (আয়তন - ml/Liter)'),
                            ),
                            DropdownMenuItem(
                              value: UnitCategory.count,
                              child: Text('Count (সংখ্যা - Piece/Dozen)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        // Base Unit (Read-only field)
                        TextFormField(
                          key: ValueKey('baseUnit_$_selectedCategory'),
                          initialValue: _currentBaseUnitLabel,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Base Unit (অভ্যন্তরীণ বেস একক)',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Base Unit Price
                        TextFormField(
                          controller: _baseUnitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Base Unit Price (৳) *',
                            prefixIcon: const Icon(Icons.sell_outlined, color: AppTheme.primaryGreen),
                            hintText: _selectedCategory == UnitCategory.weight
                                ? 'প্রতি গ্রামের দাম (যেমন: 0.28)'
                                : _selectedCategory == UnitCategory.volume
                                    ? 'প্রতি মি.লি. এর দাম (যেমন: 0.19)'
                                    : 'প্রতি পিসের দাম (যেমন: 55)',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'বেস ইউনিটের বিক্রয় মূল্য দিন';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'সঠিক মূল্য দিন (০-এর বেশি)';
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Opening Stock
                        TextFormField(
                          controller: _openingStockController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: _selectedCategory != UnitCategory.count,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Opening Stock (প্রাথমিক স্টক - বেস এককে) *',
                            prefixIcon: const Icon(Icons.inventory_rounded, color: AppTheme.primaryGreen),
                            hintText: _selectedCategory == UnitCategory.weight
                                ? 'গ্রামে লিখুন (যেমন: 5000)'
                                : _selectedCategory == UnitCategory.volume
                                    ? 'মি.লি. এ লিখুন (যেমন: 10000)'
                                    : 'পিসে লিখুন (যেমন: 25)',
                          ),
                          onChanged: (_) => setState(() {}), // Refresh live helper text
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'স্টক পরিমাণ দিন';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0) return 'সঠিক সংখ্যা দিন';
                            if (_selectedCategory == UnitCategory.count && parsed != parsed.roundToDouble()) {
                              return 'সংখ্যা পণ্যের স্টক অবশ্যই পূর্ণসংখ্যা হতে হবে';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Live Helper Text
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'সমতুল্য স্টক: $_liveStockHelperText',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                    fontSize: 13,
                                  ),
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
                    onPressed: _isSubmitting ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: _isSubmitting
                        ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                        : Text(
                            isEditing ? 'পণ্য সংশোধন আপডেট করুন' : 'পণ্য প্রস্তুত ও সংরক্ষণ করুন',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
