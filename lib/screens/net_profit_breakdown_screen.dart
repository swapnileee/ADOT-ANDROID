import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../models/product_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class NetProfitBreakdownScreen extends StatefulWidget {
  final Function(int)? onSelectTab;

  const NetProfitBreakdownScreen({super.key, this.onSelectTab});

  @override
  State<NetProfitBreakdownScreen> createState() => _NetProfitBreakdownScreenState();
}

class _NetProfitBreakdownScreenState extends State<NetProfitBreakdownScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  String _selectedFilter = 'আজ'; // 'আজ', 'এই সপ্তাহ', 'এই মাস', 'সব'

  // Master In-Memory Data Lists
  List<SaleModel> _allSales = [];
  List<ExpenseModel> _allExpenses = [];
  List<ProductModel> _allProducts = [];

  // Filtered Metric State
  double _totalSales = 0.0;
  double _totalCogs = 0.0;
  double _totalExpenses = 0.0;
  int _salesCount = 0;
  int _expensesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      final expenses = await _supabaseService.fetchExpenses();
      final products = await _supabaseService.fetchProducts();

      if (!mounted) return;
      _allSales = sales;
      _allExpenses = expenses;
      _allProducts = products;

      _applyFilterLocally();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  void _applyFilterLocally() {
    final productPrices = <String, double>{};
    for (var p in _allProducts) {
      productPrices[p.name.trim().toLowerCase()] = p.buyingPrice;
      if (p.id.toString().isNotEmpty) {
        productPrices[p.id.toString()] = p.buyingPrice;
      }
    }

    final now = DateTime.now();

    bool isDateInFilter(DateTime? date) {
      if (date == null) return false;
      if (_selectedFilter == 'সব') return true;

      final localDate = date.toLocal();

      if (_selectedFilter == 'আজ') {
        return localDate.year == now.year &&
            localDate.month == now.month &&
            localDate.day == now.day;
      } else if (_selectedFilter == 'এই সপ্তাহ') {
        final startOfWeek = DateTime(now.year, now.month, now.day, 0, 0, 0)
            .subtract(Duration(days: now.weekday - 1));
        return !localDate.isBefore(startOfWeek);
      } else if (_selectedFilter == 'এই মাস') {
        final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
        final startOfWeek = DateTime(now.year, now.month, now.day, 0, 0, 0)
            .subtract(Duration(days: now.weekday - 1));
        final effectiveStart = startOfWeek.isBefore(startOfMonth) ? startOfWeek : startOfMonth;
        return !localDate.isBefore(effectiveStart);
      }
      return true;
    }

    double salesSum = 0.0;
    double cogsSum = 0.0;
    int sCount = 0;

    for (var s in _allSales) {
      if (isDateInFilter(s.createdAt)) {
        salesSum += s.totalPrice;
        sCount++;
        final key = s.productName.trim().toLowerCase();
        final unitCost = productPrices[key] ?? (s.totalPrice * 0.70);
        cogsSum += (s.quantity * unitCost);
      }
    }

    double expensesSum = 0.0;
    int eCount = 0;
    for (var e in _allExpenses) {
      final expDate = e.expenseDate ?? e.createdAt;
      if (isDateInFilter(expDate)) {
        expensesSum += e.amount;
        eCount++;
      }
    }

    setState(() {
      _totalSales = salesSum;
      _totalCogs = cogsSum;
      _totalExpenses = expensesSum;
      _salesCount = sCount;
      _expensesCount = eCount;
      _isLoading = false;
    });
  }

  double get _grossProfit => _totalSales - _totalCogs;
  double get _netProfit => _totalSales - _totalCogs - _totalExpenses;
  double get _profitMargin => _totalSales > 0 ? (_netProfit / _totalSales) * 100 : 0.0;

  String get _statusBadgeText {
    final isProfit = _netProfit >= 0;
    final suffix = isProfit ? 'নিট লাভ হয়েছে' : 'ক্ষতি হয়েছে';

    String timePeriod = 'ব্যবসায়';
    if (_selectedFilter == 'আজ') {
      timePeriod = 'আজকে';
    } else if (_selectedFilter == 'এই সপ্তাহ') {
      timePeriod = 'এই সপ্তাহে';
    } else if (_selectedFilter == 'এই মাস') {
      timePeriod = 'এই মাসে';
    } else if (_selectedFilter == 'সব') {
      timePeriod = 'সর্বমোট';
    }

    return '$timePeriod $suffix';
  }

  @override
  Widget build(BuildContext context) {
    const deepGreenColor = Color(0xFF0B4D2C);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: AppDrawer(
        currentTab: 0,
        onSelectTab: (tabIndex) {
          Navigator.pop(context);
          if (widget.onSelectTab != null) {
            widget.onSelectTab!(tabIndex);
          }
        },
      ),
      appBar: AppBar(
        backgroundColor: deepGreenColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (widget.onSelectTab != null) {
              widget.onSelectTab!(0);
            }
          },
          tooltip: 'ড্যাশবোর্ডে ফিরে যান',
        ),
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'নিট লাভ (Net Profit)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              'লাভ-ক্ষতি ও মার্জিন বিশ্লেষণ',
              style: TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: deepGreenColor,
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: deepGreenColor,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
                  children: [
                    // 1. Time Filter Chips Row (Instant Local Filtering)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['আজ', 'এই সপ্তাহ', 'এই মাস', 'সব'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              selectedColor: deepGreenColor,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textDark,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedFilter = filter);
                                  _applyFilterLocally();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Top Deep-Green Summary Hero Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B4D2C), Color(0xFF135232)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: deepGreenColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.show_chart_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'নিট লাভ ($_selectedFilter)',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.bar_chart_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'মার্জিন: ${_profitMargin.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '৳ ${_netProfit.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _netProfit >= 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: _netProfit >= 0 ? const Color(0xFFB9F6CA) : const Color(0xFFFF8A80),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _statusBadgeText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Bottom 3-Column Metrics Breakdown
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildHeroColumnMetric(
                                        icon: Icons.shopping_bag_outlined,
                                        label: 'মোট বিক্রয়',
                                        value: '৳ ${_totalSales.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    Container(height: 24, width: 1, color: Colors.white24),
                                    Expanded(
                                      child: _buildHeroColumnMetric(
                                        icon: Icons.remove_circle_outline,
                                        label: 'মোট খরচ',
                                        value: '৳ ${(_totalCogs + _totalExpenses).toStringAsFixed(0)}',
                                      ),
                                    ),
                                    Container(height: 24, width: 1, color: Colors.white24),
                                    Expanded(
                                      child: _buildHeroColumnMetric(
                                        icon: Icons.trending_up_rounded,
                                        label: 'নিট লাভ',
                                        value: '৳ ${_netProfit.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                    ),

                    const SizedBox(height: 20),

                    // 3. Calculation Title Header
                    const Text(
                      'হিসাব বিবরণী (Step-by-Step Formula Breakdown)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),

                    // 4. Breakdown Items List Card
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.cardBorderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildBreakdownRow(
                              title: 'মোট বিক্রয় (Total Sales)',
                              subtitle: '$_salesCount টি অর্ডার হতে মোট বিক্রয়',
                              amount: _totalSales,
                              isAddition: true,
                              icon: Icons.add_circle_outline,
                              color: const Color(0xFF2E7D32),
                              bgColor: const Color(0xFFE8F5E9),
                            ),
                            Divider(height: 24, thickness: 1, color: Colors.grey.shade200),
                            _buildBreakdownRow(
                              title: 'পণ্য ক্রয়মূল্য (Cost of Goods Sold)',
                              subtitle: 'বিক্রিত পণ্যের কেনা দাম',
                              amount: _totalCogs,
                              isAddition: false,
                              icon: Icons.remove_circle_outline,
                              color: const Color(0xFFEF6C00),
                              bgColor: const Color(0xFFFFF3E0),
                            ),
                            Divider(height: 24, thickness: 1, color: Colors.grey.shade200),
                            _buildBreakdownRow(
                              title: 'গ্রস প্রফিট (Gross Profit)',
                              subtitle: 'বিক্রি - পণ্য ক্রয়মূল্য',
                              amount: _grossProfit,
                              isAddition: true,
                              isBold: true,
                              icon: Icons.show_chart_rounded,
                              color: const Color(0xFF1565C0),
                              bgColor: const Color(0xFFE3F2FD),
                            ),
                            Divider(height: 24, thickness: 1, color: Colors.grey.shade200),
                            _buildBreakdownRow(
                              title: 'দৈনন্দিন খরচ (Total Expenses)',
                              subtitle: '$_expensesCount টি পরিচালন খরচ',
                              amount: _totalExpenses,
                              isAddition: false,
                              icon: Icons.remove_circle_outline,
                              color: const Color(0xFFD32F2F),
                              bgColor: const Color(0xFFFFEBEE),
                            ),
                            Divider(height: 24, thickness: 1.5, color: Colors.grey.shade300),
                            _buildBreakdownRow(
                              title: 'সর্বমোট নিট লাভ (Net Profit)',
                              subtitle: 'নিট লাভ = গ্রস প্রফিট - খরচ',
                              amount: _netProfit,
                              isAddition: _netProfit >= 0,
                              isBold: true,
                              icon: Icons.account_balance_wallet_rounded,
                              color: deepGreenColor,
                              bgColor: const Color(0xFFE8F5E9),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Educational Note Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: deepGreenColor, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'নিট লাভ হলো প্রতিষ্ঠানের প্রকৃত মুনাফা। এখান থেকে কেনা দাম ও পরিচালন খরচ বাদ দিয়ে চূড়ান্ত লাভ হিসাব করা হয়েছে।',
                              style: TextStyle(fontSize: 12, color: deepGreenColor, fontWeight: FontWeight.w500),
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
  }

  Widget _buildHeroColumnMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow({
    required String title,
    required String subtitle,
    required double amount,
    required bool isAddition,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isBold = false,
  }) {
    final prefix = isAddition ? '+ ' : '- ';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '$prefix৳ ${amount.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
