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

  late TextEditingController _nameController;
  late TextEditingController _supplierController;
  late TextEditingController _imageUrlController;

  String _selectedCategory = 'তেল';
  String _selectedBaseUnit = 'ml';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'তেল',
    'শস্য ও ডাল',
    'মধু',
    'ডিম ও দুধ',
    'ফল',
    'সাধারণ',
  ];

  final List<String> _baseUnits = ['ml', 'g', 'pcs', 'L', 'kg'];

  // List of dynamic variant row controllers
  final List<Map<String, dynamic>> _variantRows = [];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _supplierController = TextEditingController(text: p?.supplier ?? 'ADOT Organic');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');

    if (p != null) {
      _selectedCategory = _categories.contains(p.category) ? p.category : _categories.first;
      _selectedBaseUnit = _baseUnits.contains(p.baseUnit) ? p.baseUnit : _baseUnits.first;
      if (p.variants.isNotEmpty) {
        for (var v in p.variants) {
          _variantRows.add({
            'id': v.id,
            'sizeController': TextEditingController(text: v.sizeLabel),
            'priceController': TextEditingController(text: v.price.toStringAsFixed(0)),
            'stockController': TextEditingController(text: v.stock == v.stock.roundToDouble() ? v.stock.toInt().toString() : v.stock.toString()),
          });
        }
      }
    }

    // Default variant row if list is empty
    if (_variantRows.isEmpty) {
      _addVariantRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _supplierController.dispose();
    _imageUrlController.dispose();
    for (var row in _variantRows) {
      row['sizeController']?.dispose();
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
      row['priceController']?.dispose();
      row['stockController']?.dispose();
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_variantRows.isEmpty) {
      CustomSnackBar.showWarning(context, 'অনুগ্রহ করে অন্তত একটি ভ্যারিয়েন্ট যোগ করুন');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final List<ProductVariant> variants = [];
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

      final product = Product(
        id: widget.productToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
        title: Text(isEditing ? 'পণ্য সংশোধন / এডিট' : 'পণ্য যোগ/এডিট'),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _saveProduct,
            icon: _isSubmitting
                ? const SpinKitThreeBounce(color: Colors.white, size: 16)
                : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            label: const Text(
              'সংরক্ষণ করুন',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info Inputs Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'সাধারণ তথ্য (Basic Info)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 14),

                        // Image Picker / URL Input
                        TextFormField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'ছবি URL (ছবি যোগ করুন / Image Link)',
                            prefixIcon: Icon(Icons.image_outlined, color: AppTheme.primaryGreen),
                            hintText: 'https://images.unsplash.com/...',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Product Name Input
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'পণ্যের নাম *',
                            prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen),
                            hintText: 'যেমন: সরিষার তেল / সুন্দরবনের মধু',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'পণ্যের নাম দিন' : null,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            // Category Dropdown
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'ক্যাটাগরি *',
                                  prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primaryGreen),
                                ),
                                items: _categories.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Base Unit Dropdown
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBaseUnit,
                                decoration: const InputDecoration(
                                  labelText: 'বেস ইউনিট *',
                                  prefixIcon: Icon(Icons.straighten_rounded, color: AppTheme.primaryGreen),
                                ),
                                items: _baseUnits.map((u) {
                                  return DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u, style: const TextStyle(fontWeight: FontWeight.bold)),
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

                        // Supplier Input
                        TextFormField(
                          controller: _supplierController,
                          decoration: const InputDecoration(
                            labelText: 'সরবরাহকারী (Supplier Name)',
                            prefixIcon: Icon(Icons.storefront_outlined, color: AppTheme.primaryGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Dynamic Variant Table Header & Add Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ভ্যারিয়েন্ট সমূহ (Variants List)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addVariantRow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('+ ভ্যারিয়েন্ট যোগ করুন', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Dynamic Variant Table
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Column Headers: সাইজ/লেবেল | মূল্য (৳) | স্টক | Action (Delete Icon)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreenBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('সাইজ/লেবেল *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              SizedBox(width: 8),
                              Expanded(flex: 3, child: Text('মূল্য (৳) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              SizedBox(width: 8),
                              Expanded(flex: 3, child: Text('স্টক *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              SizedBox(width: 36, child: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Dynamic Variant Rows
                        ..._variantRows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Size Label Input
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: row['sizeController'] as TextEditingController,
                                    decoration: const InputDecoration(
                                      hintText: 'যেমন: 250 ml',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'সাইজ দিন' : null,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Price Input
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: row['priceController'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '৳ মূল্য',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'মূল্য দিন';
                                      if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Stock Input
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: row['stockController'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: 'স্টক',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'স্টক দিন';
                                      if (double.tryParse(v.trim()) == null) return 'সংখ্যা';
                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(width: 4),

                                // Delete Action Icon
                                SizedBox(
                                  width: 36,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 22),
                                    onPressed: () => _removeVariantRow(index),
                                    tooltip: 'ভ্যারিয়েন্ট মুছুন',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Footer Note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'আপনি প্রতিটি ভ্যারিয়েন্টের জন্য আলাদা মূল্য ও স্টক সেট করতে পারবেন।',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Main Action Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSubmitting ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: _isSubmitting
                        ? const SpinKitThreeBounce(color: Colors.white, size: 22)
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
