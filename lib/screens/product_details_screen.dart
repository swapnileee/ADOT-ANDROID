import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../theme/app_theme.dart';
import 'add_product_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  double get _minVariantStock {
    if (_product.variants.isEmpty) return 0;
    return _product.variants.map((v) => v.stock).reduce((a, b) => a < b ? a : b);
  }

  double get _maxVariantStock {
    if (_product.variants.isEmpty) return 0;
    return _product.variants.map((v) => v.stock).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(productToEdit: _product),
      ),
    );

    if (updated == true) {
      if (!mounted) return;
      Navigator.pop(context, true); // Pop with refresh indicator
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('পণ্যের বিস্তারিত'),
        actions: [
          TextButton.icon(
            onPressed: _navigateToEdit,
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            label: const Text(
              'এডিট',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Main Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreenBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _product.imageUrl.isNotEmpty
                              ? Image.network(
                                  _product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.eco_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 40,
                                  ),
                                )
                              : const Icon(
                                  Icons.eco_rounded,
                                  color: AppTheme.primaryGreen,
                                  size: 40,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title & Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _product.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ক্যাটাগরি: ${_product.category}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'সরবরাহকারী: ${_product.supplier}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_product.variants.length} টি ভ্যারিয়েন্ট',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _product.isLowStock
                                        ? AppTheme.errorRed.withValues(alpha: 0.1)
                                        : AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'মোট স্টক: ${_product.formattedStock}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _product.isLowStock ? AppTheme.errorRed : AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Variant Table Header & Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ভ্যারিয়েন্ট সমূহ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _navigateToEdit,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primaryGreen),
                    label: const Text(
                      '+ ভ্যারিয়েন্ট যোগ করুন',
                      style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Variant Table Card (Columns: সাইজ | মূল্য (৳) | স্টক) -> NO Barcode Column
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Table Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('সাইজ/লেবেল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('মূল্য (৳)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('স্টক পরিমাণ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Table Data Rows
                      ..._product.variants.map((variant) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.cardBorderColor, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  variant.sizeLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '৳ ${variant.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${variant.stock == variant.stock.roundToDouble() ? variant.stock.toInt() : variant.stock} ${_product.baseUnit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: variant.stock <= 5 ? AppTheme.errorRed : AppTheme.textDark,
                                    fontSize: 13,
                                  ),
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

              const SizedBox(height: 24),

              // Stock Summary Cards (স্টক সারাংশ: মোট স্টক, সর্বনিম্ন স্টক, সর্বোচ্চ স্টক)
              const Text(
                'স্টক সারাংশ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'মোট স্টক',
                      value: '${_product.totalStock == _product.totalStock.roundToDouble() ? _product.totalStock.toInt() : _product.totalStock} ${_product.baseUnit}',
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.primaryGreen,
                      bgColor: AppTheme.lightGreenBg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'সর্বনিম্ন স্টক',
                      value: '${_minVariantStock == _minVariantStock.roundToDouble() ? _minVariantStock.toInt() : _minVariantStock} ${_product.baseUnit}',
                      icon: Icons.vertical_align_bottom_rounded,
                      color: AppTheme.warningOrange,
                      bgColor: const Color(0xFFFEF3C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'সর্বোচ্চ স্টক',
                      value: '${_maxVariantStock == _maxVariantStock.roundToDouble() ? _maxVariantStock.toInt() : _maxVariantStock} ${_product.baseUnit}',
                      icon: Icons.vertical_align_top_rounded,
                      color: AppTheme.primaryGreen,
                      bgColor: AppTheme.lightGreenBg,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
