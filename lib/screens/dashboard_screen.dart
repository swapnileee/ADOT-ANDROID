import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_snackbar.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'universal_search_screen.dart';
import 'add_product_screen.dart';
import 'low_stock_screen.dart';
import 'dues_screen.dart';
import 'stock_in_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToPOS;
  final VoidCallback onNavigateToInventory;
  final VoidCallback? onNavigateToOrders;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPOS,
    required this.onNavigateToInventory,
    this.onNavigateToOrders,
  });

  // Brand Palette Constants
  static const Color primaryGreen = Color(0xFF1E4632);
  static const Color cardGreen = Color(0xFF163E2B);
  static const Color bgGray = Color(0xFFF4F6F5);
  static const Color textDark = Color(0xFF1F2937);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  double _todaySales = 0.0;
  double _todayExpenses = 0.0;
  double _todayNetProfit = 0.0;
  double _totalDue = 0.0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  int _todayOrderCount = 0;
  List<SaleModel> _recentSales = [];
  List<SaleModel> _allSales = [];

  // Interactive Filter & Notification Badge State
  String _selectedSalesFilter = 'আজ';
  int _unreadNotificationCount = 3;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String get _formattedCurrentDate {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM yyyy').format(now);
  }

  double get _cashInHand {
    final net = _todaySales - _todayExpenses;
    return net > 0 ? net : 0.0;
  }

  double get _displayedSalesAmount {
    final now = DateTime.now();
    DateTime startCurrent;
    DateTime endCurrent = now;

    switch (_selectedSalesFilter) {
      case 'এই সপ্তাহ':
        startCurrent = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case 'এই মাস':
        startCurrent = DateTime(now.year, now.month, 1);
        break;
      case 'এই বছর':
        startCurrent = DateTime(now.year, 1, 1);
        break;
      case 'আজ':
      default:
        startCurrent = DateTime(now.year, now.month, now.day);
        break;
    }

    double total = 0.0;
    for (var sale in _allSales) {
      if (sale.createdAt != null &&
          sale.createdAt!.isAfter(startCurrent.subtract(const Duration(milliseconds: 1))) &&
          sale.createdAt!.isBefore(endCurrent.add(const Duration(milliseconds: 1)))) {
        total += sale.totalPrice;
      }
    }
    return total;
  }

  double get _displayedPreviousSalesAmount {
    final now = DateTime.now();
    DateTime startPrev;
    DateTime endPrev;

    switch (_selectedSalesFilter) {
      case 'এই সপ্তাহ':
        final startCurrent = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        startPrev = startCurrent.subtract(const Duration(days: 7));
        endPrev = startCurrent.subtract(const Duration(milliseconds: 1));
        break;
      case 'এই মাস':
        final startCurrent = DateTime(now.year, now.month, 1);
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        startPrev = DateTime(prevYear, prevMonth, 1);
        endPrev = startCurrent.subtract(const Duration(milliseconds: 1));
        break;
      case 'এই বছর':
        final startCurrent = DateTime(now.year, 1, 1);
        startPrev = DateTime(now.year - 1, 1, 1);
        endPrev = startCurrent.subtract(const Duration(milliseconds: 1));
        break;
      case 'আজ':
      default:
        final startCurrent = DateTime(now.year, now.month, now.day);
        startPrev = startCurrent.subtract(const Duration(days: 1));
        endPrev = startCurrent.subtract(const Duration(milliseconds: 1));
        break;
    }

    double total = 0.0;
    for (var sale in _allSales) {
      if (sale.createdAt != null &&
          sale.createdAt!.isAfter(startPrev.subtract(const Duration(milliseconds: 1))) &&
          sale.createdAt!.isBefore(endPrev.add(const Duration(milliseconds: 1)))) {
        total += sale.totalPrice;
      }
    }
    return total;
  }

  double get _displayedGrowthPercentage {
    final current = _displayedSalesAmount;
    final previous = _displayedPreviousSalesAmount;

    if (previous > 0) {
      return ((current - previous) / previous) * 100.0;
    } else if (current > 0) {
      return 100.0;
    } else {
      return 0.0;
    }
  }

  String get _displayedComparisonText {
    switch (_selectedSalesFilter) {
      case 'এই সপ্তাহ':
        return 'গত সপ্তাহের তুলনায়';
      case 'এই মাস':
        return 'গত মাসের তুলনায়';
      case 'এই বছর':
        return 'গত বছরের তুলনায়';
      case 'আজ':
      default:
        return 'গতকালকের তুলনায়';
    }
  }

  String get _displayedPreviousAmountText {
    final prevAmount = _displayedPreviousSalesAmount;
    switch (_selectedSalesFilter) {
      case 'এই সপ্তাহ':
        return 'গত সপ্তাহ: ৳ ${prevAmount.toStringAsFixed(0)}';
      case 'এই মাস':
        return 'গত মাস: ৳ ${prevAmount.toStringAsFixed(0)}';
      case 'এই বছর':
        return 'গত বছর: ৳ ${prevAmount.toStringAsFixed(0)}';
      case 'আজ':
      default:
        return 'গতকাল: ৳ ${prevAmount.toStringAsFixed(0)}';
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _supabaseService.fetchDashboardStats();
      final sales = await _supabaseService.fetchSales();
      final products = await _supabaseService.fetchProducts();

      int outCount = 0;
      for (var p in products) {
        if (p.totalStock <= 0) outCount++;
      }

      if (!mounted) return;
      setState(() {
        _todaySales = stats['todaySales'] ?? 0.0;
        _todayExpenses = stats['todayExpenses'] ?? 0.0;
        _todayNetProfit = (stats['todayNetProfit'] as num?)?.toDouble() ?? (_todaySales - _todayExpenses - (_todaySales * 0.70));
        _totalDue = stats['totalDue'] ?? 0.0;
        _totalProducts = stats['totalProducts'] ?? 0;
        _lowStockCount = stats['lowStockCount'] ?? 0;
        _todayOrderCount = (stats['todayOrderCount'] as int?) ?? 0;
        _outOfStockCount = outCount;
        _allSales = sales;
        _recentSales = sales.take(5).toList();
        _unreadNotificationCount = _lowStockCount > 0 ? 3 : 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ড্যাশবোর্ড ডাটা লোড করতে সমস্যা হয়েছে: $e');
    }
  }

  void _showAddExpenseModal() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DashboardScreen.bgGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'নতুন খরচ যোগ করুন',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DashboardScreen.primaryGreen,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'খরচের বিবরণ/শিরোনাম *',
                        prefixIcon: Icon(Icons.description_outlined, color: DashboardScreen.primaryGreen),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'বিবরণ প্রদান করুন' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'টাকার পরিমাণ (৳) *',
                        prefixIcon: Icon(Icons.attach_money_rounded, color: DashboardScreen.primaryGreen),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'টাকার পরিমাণ প্রদান করুন';
                        if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা প্রদান করুন';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'অতিরিক্ত নোট (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: DashboardScreen.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);
                                try {
                                  final expense = ExpenseModel(
                                    title: titleController.text.trim(),
                                    amount: double.parse(amountController.text.trim()),
                                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  );
                                  await _supabaseService.addExpense(expense);
                                  if (!context.mounted) return;
                                  CustomSnackBar.showSuccess(context, 'খরচ সফলভাবে সংরক্ষিত হয়েছে!');
                                  Navigator.pop(context);
                                  _loadDashboardData();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  CustomSnackBar.showError(context, 'খরচ যোগ করতে ত্রুটি: $e');
                                } finally {
                                  setModalState(() => isSubmitting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardScreen.primaryGreen,
                        ),
                        child: isSubmitting
                            ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                            : const Text('খরচ সংরক্ষণ করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        );
      },
    );
  }

  Future<void> _showAddProductModal() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductScreen(),
      ),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  void _showNotificationCenter() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: DashboardScreen.primaryGreen),
              SizedBox(width: 8),
              Text('নোটিফিকেশন সেন্টার', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
                title: Text('$_lowStockCount টি পণ্যে কম স্টক রয়েছে'),
                subtitle: const Text('স্টক রি-অর্ডার করার অনুরোধ করা হচ্ছে'),
              ),
              const Divider(),
              const ListTile(
                dense: true,
                leading: Icon(Icons.people_outline_rounded, color: AppTheme.warningOrange),
                title: Text('কর্মচারীদের বকেয়া বেতন'),
                subtitle: Text('চলতি মাসের ১ জনের বেতন প্রক্রিয়াধীন'),
              ),
              const Divider(),
              const ListTile(
                dense: true,
                leading: Icon(Icons.mark_email_unread_rounded, color: DashboardScreen.primaryGreen),
                title: Text('গ্রাহকদের বকেয়া তাগাদা'),
                subtitle: Text('আজকের ৩টি বকেয়া তাগাদা অনুস্মারক'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _unreadNotificationCount = 0;
                });
                Navigator.pop(dialogContext);
                CustomSnackBar.showSuccess(context, 'সকল নোটিফিকেশন ক্লিয়ার করা হয়েছে!');
              },
              child: const Text('সব ক্লিয়ার করুন', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: DashboardScreen.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardScreen.bgGray,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: DashboardScreen.primaryGreen,
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: DashboardScreen.primaryGreen,
                  size: 40.0,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. TOP CURVED HEADER
                    _buildTopHeader(context),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. TODAY SUMMARY STRIP
                          _buildTodaySummaryStrip(),
                          const SizedBox(height: 12),

                          // 3. MAIN CARDS: TODAY'S SALES
                          _buildMainMetricsCards(),
                          const SizedBox(height: 12),

                          // 4. 2x2 GRID (PROFIT, EXPENSE, CASH, DUE)
                          _buildSecondaryMetricsGrid(),
                          const SizedBox(height: 16),

                          // 5. QUICK ACTIONS
                          _buildQuickActions(),
                          const SizedBox(height: 16),

                          // 6. IMPORTANT ALERTS
                          _buildAlertsSection(),
                          const SizedBox(height: 16),

                          // 7. RECENT SALES
                          _buildRecentSalesSection(),
                          const SizedBox(height: 16),

                          // 8. INVENTORY SUMMARY
                          _buildInventorySummaryCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // 1. HEADER WIDGET (Clean Centered Layout)
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: DashboardScreen.primaryGreen,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'মেনু খুলুন',
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white24,
            child: Text(
              'ADOT',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ADOT Organic Store',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _formattedCurrentDate,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UniversalSearchScreen()),
              );
            },
            tooltip: 'খুঁজুন',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                onPressed: _showNotificationCenter,
                tooltip: 'নোটিফিকেশন',
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. TODAY SUMMARY STRIP
  Widget _buildTodaySummaryStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('আজকের সারসংক্ষেপ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DashboardScreen.textDark)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStripItem(Icons.shopping_cart_outlined, '$_todayOrderCount টি', 'অর্ডার', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                const SizedBox(width: 16),
                _buildStripItem(Icons.payments_outlined, '৳ ${_todaySales.toStringAsFixed(0)}', 'মোট বিক্রি', const Color(0xFFFFF3E0), const Color(0xFFEF6C00)),
                const SizedBox(width: 16),
                _buildStripItem(Icons.people_outline, '৩ জন', 'বকেয়া গ্রাহক', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
                const SizedBox(width: 16),
                _buildStripItem(Icons.inventory_2_outlined, '$_lowStockCount টি', 'কম স্টক পণ্য', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStripItem(IconData icon, String value, String label, Color bgColor, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
          ],
        )
      ],
    );
  }

  // 3. MAIN METRICS (GREEN CARD WITH INTERACTIVE FILTER)
  Widget _buildMainMetricsCards() {
    final double growth = _displayedGrowthPercentage;
    final bool isPositive = growth >= 0;
    final Color accentColor = isPositive ? Colors.greenAccent : Colors.orangeAccent;
    final IconData arrowIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DashboardScreen.cardGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_selectedSalesFilter-এর বিক্রি',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    _selectedSalesFilter = value;
                  });
                },
                color: DashboardScreen.cardGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'আজ', child: Text('আজ', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'এই সপ্তাহ', child: Text('এই সপ্তাহ', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'এই মাস', child: Text('এই মাস', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'এই বছর', child: Text('এই বছর', style: TextStyle(color: Colors.white, fontSize: 13))),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text('$_selectedSalesFilter ▼', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('৳ ${_displayedSalesAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(arrowIcon, color: accentColor, size: 12),
                    const SizedBox(width: 2),
                    Text('${growth.abs().toStringAsFixed(0)}%', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(_displayedComparisonText, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12),
          Text(_displayedPreviousAmountText, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _buildSecondaryCard('নিট লাভ', '৳ ${_todayNetProfit.toStringAsFixed(0)}', '+১২% গতকালের তুলনায়', Icons.trending_up, const Color(0xFF2E7D32)),
        _buildSecondaryCard('মোট খরচ', '৳ ${_todayExpenses.toStringAsFixed(0)}', '-৮% গতকালের তুলনায়', Icons.trending_down, const Color(0xFFD32F2F)),
        _buildSecondaryCard('হাতে নগদ', '৳ ${_cashInHand.toStringAsFixed(0)}', 'আপডেট: আজ ১০:১৫ AM', Icons.account_balance_wallet_outlined, const Color(0xFF1565C0)),
        _buildSecondaryCard('বকেয়া আদায়যোগ্য', '৳ ${_totalDue.toStringAsFixed(0)}', '৩ জন গ্রাহকের কাছে', Icons.receipt_outlined, const Color(0xFFEF6C00)),
      ],
    );
  }

  Widget _buildSecondaryCard(String title, String amount, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(amount, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 9, color: Colors.black38), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // 5. QUICK ACTIONS
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('কুইক অ্যাকশন', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DashboardScreen.textDark)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton('নতুন বিক্রি', Icons.add_shopping_cart, const Color(0xFF2E7D32), widget.onNavigateToPOS),
            _buildActionButton('পণ্য যোগ', Icons.add_box_outlined, const Color(0xFF1565C0), _showAddProductModal),
            _buildActionButton('নতুন ক্রয়', Icons.shopping_bag_outlined, const Color(0xFF6A1B9A), () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StockInScreen()),
              ).then((_) => _loadDashboardData());
            }),
            _buildActionButton('খরচ যোগ', Icons.money_off_outlined, const Color(0xFFEF6C00), _showAddExpenseModal),
          ],
        )
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DashboardScreen.textDark)),
          ],
        ),
      ),
    );
  }

  // 6. ALERTS SECTION
  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('জরুরি অ্যালার্ট', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 10),
          _buildAlertItem(
            'কম স্টক পণ্য',
            '$_lowStockCountটি পণ্যের স্টক কমে গেছে',
            'দেখুন',
            Colors.redAccent,
            () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LowStockScreen()));
            },
          ),
          const Divider(height: 16),
          _buildAlertItem(
            'কর্মচারী বেতন',
            '১ জনের বেতন বকেয়া আছে',
            'বেতন দিন',
            Colors.orange,
            () => CustomSnackBar.showInfo(context, 'কর্মচারী বেতন মডিউল শীঘ্রই আসছে!'),
          ),
          const Divider(height: 16),
          _buildAlertItem(
            'কাস্টমার বকেয়া',
            '৳ ${_totalDue.toStringAsFixed(0)} টাকা পাওয়ার সময় পার হয়েছে',
            'আদায় করুন',
            Colors.green,
            () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DuesScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String title, String desc, String btn, Color color, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black45)),
              ],
            )
          ],
        ),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(btn, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  // 7. RECENT SALES
  Widget _buildRecentSalesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('সাম্প্রতিক বিক্রি', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DashboardScreen.textDark)),
          const SizedBox(height: 10),
          _recentSales.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(child: Text('এখনও কোন বিক্রি রেকর্ড পাওয়া যায়নি', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _recentSales.length > 3 ? 3 : _recentSales.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final sale = _recentSales[index];
                    final String timeStr = sale.createdAt != null ? DateFormat('h:mm a').format(sale.createdAt!) : 'আজ';
                    final bool isPaid = sale.dueAmount <= 0;

                    return _buildSaleRow(
                      sale.customerName.isEmpty ? 'নগদ ক্রেতা' : sale.customerName,
                      timeStr,
                      '৳ ${sale.totalPrice.toStringAsFixed(0)}',
                      isPaid ? 'পরিশোধিত' : 'বকেয়া',
                      isPaid ? Colors.green : Colors.orange,
                    );
                  },
                ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: widget.onNavigateToOrders ?? widget.onNavigateToPOS,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('সকল বিক্রি দেখুন >', style: TextStyle(color: DashboardScreen.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSaleRow(String name, String time, String amount, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(time, style: const TextStyle(fontSize: 10, color: Colors.black38)),
          ],
        ),
        Row(
          children: [
            Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
            )
          ],
        )
      ],
    );
  }

  // 8. INVENTORY SUMMARY
  Widget _buildInventorySummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInvCol('মোট পণ্য', '$_totalProductsটি', const Color(0xFF2E7D32)),
          Container(height: 20, width: 1, color: Colors.black12),
          _buildInvCol('কম স্টক', '$_lowStockCountটি', const Color(0xFFEF6C00)),
          Container(height: 20, width: 1, color: Colors.black12),
          _buildInvCol('আউট অফ স্টক', '$_outOfStockCountটি', const Color(0xFFC62828)),
        ],
      ),
    );
  }

  Widget _buildInvCol(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(count, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
