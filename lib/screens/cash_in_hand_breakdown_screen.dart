import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/refresh_signal.dart';
import '../models/sale_model.dart';
import '../models/due_collection_model.dart';
import '../models/expense_model.dart';
import '../models/purchase_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class CashInHandBreakdownScreen extends StatefulWidget {
  final Function(int)? onSelectTab;

  const CashInHandBreakdownScreen({super.key, this.onSelectTab});

  @override
  State<CashInHandBreakdownScreen> createState() => _CashInHandBreakdownScreenState();
}

class _CashInHandBreakdownScreenState extends State<CashInHandBreakdownScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  String _selectedFilter = 'আজ'; // 'আজ', 'এই সপ্তাহ', 'এই মাস', 'সব'
  bool _isInflowExpanded = true;
  bool _isOutflowExpanded = true;

  // Master In-Memory Data Lists
  List<SaleModel> _allSales = [];
  List<DueCollectionModel> _allDueCollections = [];
  List<ExpenseModel> _allExpenses = [];
  List<PurchaseModel> _allPurchases = [];

  // Filtered Metric State
  double _directPaidSales = 0.0;
  double _cashSalesSum = 0.0;
  int _cashSalesCount = 0;
  double _bkashSalesSum = 0.0;
  int _bkashSalesCount = 0;
  double _bankSalesSum = 0.0;
  int _bankSalesCount = 0;

  double _dueCollected = 0.0;
  double _cashPurchases = 0.0;
  double _expensesPaid = 0.0;
  int _dueColCount = 0;

  @override
  void initState() {
    super.initState();
    RefreshSignal().addListener(_onRefreshSignal);
    _loadData();
  }

  void _onRefreshSignal() {
    if (mounted) _loadData();
  }

  @override
  void dispose() {
    RefreshSignal().removeListener(_onRefreshSignal);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      final dueCollections = await _supabaseService.fetchDueCollections();
      final expenses = await _supabaseService.fetchExpenses();
      final purchases = await _supabaseService.fetchPurchases();

      if (!mounted) return;
      _allSales = sales;
      _allDueCollections = dueCollections;
      _allExpenses = expenses;
      _allPurchases = purchases;

      _applyFilterLocally();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ক্যাশ তথ্য লোড করতে ব্যর্থ: $e');
    }
  }

  void _applyFilterLocally() {
    final nowUtc = DateTime.now().toUtc();
    final nowBD = nowUtc.add(const Duration(hours: 6));
    final startOfTodayBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day).subtract(const Duration(hours: 6));
    final endOfTodayBD = startOfTodayBD.add(const Duration(hours: 24));

    bool isDateInFilter(DateTime? date) {
      if (date == null) return false;
      if (_selectedFilter == 'সব') return true;

      final dateUtc = date.toUtc();

      if (_selectedFilter == 'আজ') {
        return !dateUtc.isBefore(startOfTodayBD) && dateUtc.isBefore(endOfTodayBD);
      } else if (_selectedFilter == 'এই সপ্তাহ') {
        final startOfWeekBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day, 0, 0, 0)
            .subtract(Duration(days: nowBD.weekday - 1))
            .subtract(const Duration(hours: 6));
        return !dateUtc.isBefore(startOfWeekBD);
      } else if (_selectedFilter == 'এই মাস') {
        final startOfMonthBD = DateTime.utc(nowBD.year, nowBD.month, 1, 0, 0, 0)
            .subtract(const Duration(hours: 6));
        final startOfWeekBD = DateTime.utc(nowBD.year, nowBD.month, nowBD.day, 0, 0, 0)
            .subtract(Duration(days: nowBD.weekday - 1))
            .subtract(const Duration(hours: 6));
        final effectiveStart = startOfWeekBD.isBefore(startOfMonthBD) ? startOfWeekBD : startOfMonthBD;
        return !dateUtc.isBefore(effectiveStart);
      }
      return true;
    }

    double paidSalesSum = 0.0;
    double cSalesSum = 0.0;
    int cCount = 0;
    double bSalesSum = 0.0;
    int bCount = 0;
    double bankSalesSum = 0.0;
    int bankCount = 0;

    for (var s in _allSales) {
      if (isDateInFilter(s.createdAt)) {
        if (s.paidAmount > 0) {
          paidSalesSum += s.paidAmount;
          final methodLower = s.paymentMethod.toLowerCase();
          if (methodLower.contains('bkash') || methodLower.contains('বিকাশ')) {
            bSalesSum += s.paidAmount;
            bCount++;
          } else if (methodLower.contains('bank') || methodLower.contains('ব্যাংক') || methodLower.contains('card')) {
            bankSalesSum += s.paidAmount;
            bankCount++;
          } else {
            cSalesSum += s.paidAmount;
            cCount++;
          }
        }
      }
    }

    double dueColSum = 0.0;
    int colCount = 0;
    for (var col in _allDueCollections) {
      if (isDateInFilter(col.createdAt)) {
        dueColSum += col.amount;
        colCount++;
      }
    }

    double expSum = 0.0;
    for (var exp in _allExpenses) {
      final expDate = exp.expenseDate ?? exp.createdAt;
      if (isDateInFilter(expDate)) {
        expSum += exp.amount;
      }
    }

    double purchaseSum = 0.0;
    for (var pur in _allPurchases) {
      if (isDateInFilter(pur.createdAt)) {
        purchaseSum += pur.totalCost;
      }
    }

    setState(() {
      _directPaidSales = paidSalesSum;
      _cashSalesSum = cSalesSum;
      _cashSalesCount = cCount;
      _bkashSalesSum = bSalesSum;
      _bkashSalesCount = bCount;
      _bankSalesSum = bankSalesSum;
      _bankSalesCount = bankCount;
      _dueCollected = dueColSum;
      _expensesPaid = expSum;
      _cashPurchases = purchaseSum;
      _dueColCount = colCount;
      _isLoading = false;
    });
  }

  double get _totalInflow => _directPaidSales + _dueCollected;
  double get _totalOutflow => _cashPurchases + _expensesPaid;
  double get _cashInHand => (_totalInflow - _totalOutflow) > 0 ? (_totalInflow - _totalOutflow) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
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
        backgroundColor: const Color(0xFF1565C0),
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
              'হাতে নগদ (Cash in Hand)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              'নগদ স্থিতি ও লেনদেন বিবরণী',
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
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: Color(0xFF1565C0),
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF1565C0),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // 1. Filter Chips Row (Instant Local Filtering)
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
                              selectedColor: const Color(0xFF1565C0),
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

                    // 2. Top Blue Hero Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'হাতে নগদ ($_selectedFilter)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '৳ ${_cashInHand.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'জমা: +৳ ${_totalInflow.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F).withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'খরচ: -৳ ${_totalOutflow.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 3. Cash Inflow Section Card (Nogod Joma)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isInflowExpanded = !_isInflowExpanded),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF2E7D32), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'নগদ জমা (Cash Inflow)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        Text(
                                          'সরাসরি বিক্রি ও বকেয়া আদায়',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+ ৳ ${_totalInflow.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _isInflowExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isInflowExpanded) ...[
                            const Divider(height: 1, color: AppTheme.cardBorderColor),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  _buildSleekDetailRow(
                                    title: '১. নগদ বিক্রি (Cash)',
                                    subtitle: '$_cashSalesCount টি অর্ডারে জমা',
                                    amount: _cashSalesSum,
                                    isInflow: true,
                                    icon: Icons.account_balance_wallet_rounded,
                                    bgColor: const Color(0xFFE8F5E9),
                                    iconColor: const Color(0xFF2E7D32),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSleekDetailRow(
                                    title: '২. বিকাশ বিক্রি (Bkash)',
                                    subtitle: '$_bkashSalesCount টি অর্ডারে জমা',
                                    amount: _bkashSalesSum,
                                    isInflow: true,
                                    icon: Icons.phone_android_rounded,
                                    bgColor: const Color(0xFFFCE4EC),
                                    iconColor: const Color(0xFFD81B60),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSleekDetailRow(
                                    title: '৩. ব্যাংক বিক্রি (Bank)',
                                    subtitle: '$_bankSalesCount টি অর্ডারে জমা',
                                    amount: _bankSalesSum,
                                    isInflow: true,
                                    icon: Icons.account_balance_rounded,
                                    bgColor: const Color(0xFFE3F2FD),
                                    iconColor: const Color(0xFF1E88E5),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSleekDetailRow(
                                    title: '৪. বকেয়া আদায় (Due Collections)',
                                    subtitle: '$_dueColCount জন গ্রাহকের ডিউ শোধ',
                                    amount: _dueCollected,
                                    isInflow: true,
                                    icon: Icons.assignment_turned_in_rounded,
                                    bgColor: const Color(0xFFE0F2F1),
                                    iconColor: const Color(0xFF00897B),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Cash Outflow Section Card (Nogod Khoroch)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isOutflowExpanded = !_isOutflowExpanded),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFEBEE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFD32F2F), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'নগদ খরচ (Cash Outflow)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                        Text(
                                          'মালামাল কেনা ও দৈনন্দিন খরচ',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '- ৳ ${_totalOutflow.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _isOutflowExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isOutflowExpanded) ...[
                            const Divider(height: 1, color: AppTheme.cardBorderColor),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  _buildSleekDetailRow(
                                    title: '৩. নগদে মালামাল ক্রয় (Cash Stock Purchase)',
                                    subtitle: 'পণ্য স্টক কেনার জন্য ক্যাশ প্রদান',
                                    amount: _cashPurchases,
                                    isInflow: false,
                                    icon: Icons.remove_circle_outline,
                                    bgColor: const Color(0xFFFFF3E0),
                                    iconColor: const Color(0xFFEF6C00),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSleekDetailRow(
                                    title: '৪. দৈনন্দিন খরচ প্রদান (Expenses Paid)',
                                    subtitle: 'দোকান ভাড়া, পরিবহন ও অন্যান্য খরচ',
                                    amount: _expensesPaid,
                                    isInflow: false,
                                    icon: Icons.remove_circle_outline,
                                    bgColor: const Color(0xFFFFEBEE),
                                    iconColor: const Color(0xFFD32F2F),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Net Cash Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'নিট হাতে নগদ (Net Cash in Hand)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'ইনফ্লো - আউটফ্লো',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              Text(
                                '৳ ${_cashInHand.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'নিট স্থিতি = (নগদ জমা + বকেয়া আদায়) - (নগদে ক্রয় + খরচ)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
      ),
    );
  }

  Widget _buildSleekDetailRow({
    required String title,
    required String subtitle,
    required double amount,
    required bool isInflow,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    final prefix = isInflow ? '+ ' : '- ';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ],
    );
  }
}
