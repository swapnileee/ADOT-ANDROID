import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/refresh_signal.dart';
import '../models/sale_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  int _selectedFilterIndex = 0; // 0 = All, 1 = Paid, 2 = Due

  List<SaleModel> _allSales = [];

  @override
  void initState() {
    super.initState();
    RefreshSignal().addListener(_onRefreshSignal);
    _loadSalesData();
  }

  void _onRefreshSignal() {
    if (mounted) {
      _loadSalesData();
    }
  }

  void refreshData() {
    _loadSalesData();
  }

  @override
  void dispose() {
    RefreshSignal().removeListener(_onRefreshSignal);
    super.dispose();
  }

  Future<void> _loadSalesData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      if (!mounted) return;
      setState(() {
        _allSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'অর্ডার ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  List<SaleModel> get _filteredSales {
    if (_selectedFilterIndex == 1) {
      return _allSales.where((s) => s.dueAmount <= 0).toList();
    } else if (_selectedFilterIndex == 2) {
      return _allSales.where((s) => s.dueAmount > 0).toList();
    }
    return _allSales;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredSales;

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('অর্ডার ও ক্যাশমেমো হিসেব'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSalesData,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadSalesData,
                color: AppTheme.primaryGreen,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'অর্ডার ও ইনভয়েস পরিচিতি',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'সর্বমোট ${_allSales.length}টি বিক্রয়ের রেকর্ড সংরক্ষিত রয়েছে',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('সকল অর্ডার (${_allSales.length})'),
                            selected: _selectedFilterIndex == 0,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilterIndex == 0 ? Colors.white : AppTheme.textDark,
                              fontWeight: _selectedFilterIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilterIndex = 0);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('পরিশোধিত (${_allSales.where((s) => s.dueAmount <= 0).length})'),
                            selected: _selectedFilterIndex == 1,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilterIndex == 1 ? Colors.white : AppTheme.textDark,
                              fontWeight: _selectedFilterIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilterIndex = 1);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('বকেয়া/পেন্ডিং (${_allSales.where((s) => s.dueAmount > 0).length})'),
                            selected: _selectedFilterIndex == 2,
                            selectedColor: AppTheme.warningOrange,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _selectedFilterIndex == 2 ? Colors.white : AppTheme.textDark,
                              fontWeight: _selectedFilterIndex == 2 ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilterIndex = 2);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    filteredList.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text('কোন অর্ডার রেকর্ড পাওয়া যায়নি', style: TextStyle(color: AppTheme.textMuted)),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final sale = filteredList[index];
                              final dateStr = sale.createdAt != null
                                  ? DateFormat('dd MMM yyyy, h:mm a').format(sale.createdAt!)
                                  : 'আজ';
                              final isDue = sale.dueAmount > 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isDue
                                        ? AppTheme.warningOrange.withValues(alpha: 0.15)
                                        : AppTheme.primaryGreen.withValues(alpha: 0.15),
                                    child: Icon(
                                      isDue ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                                      color: isDue ? AppTheme.warningOrange : AppTheme.primaryGreen,
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sale.productName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '৳ ${sale.totalPrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDue ? AppTheme.warningOrange : AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ক্রেতা: ${sale.customerName.isEmpty ? "নগদ ক্রেতা" : sale.customerName}${sale.customerPhone != null && sale.customerPhone!.isNotEmpty ? " (${sale.customerPhone})" : ""} • $dateStr',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              'পরিমাণ: ${sale.displayQuantityWithUnit}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDue ? const Color(0xFFFEE2E2) : const Color(0xFFE6F4EA),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isDue ? 'বকেয়া ৳${sale.dueAmount.toStringAsFixed(0)}' : 'পরিশোধিত',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDue ? AppTheme.errorRed : AppTheme.primaryGreen,
                                                ),
                                              ),
                                            ),
                                          ],
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
              ),
      ),
    );
  }
}
