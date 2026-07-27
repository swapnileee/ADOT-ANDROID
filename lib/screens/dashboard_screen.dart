import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/custom_snackbar.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'universal_search_screen.dart';
import 'add_product_screen.dart';
import 'low_stock_screen.dart';
import 'report_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToPOS;
  final VoidCallback onNavigateToInventory;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPOS,
    required this.onNavigateToInventory,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  bool _isRecentSalesExpanded = false;
  double _todaySales = 0.0;
  double _todayExpenses = 0.0;
  double _todayNetProfit = 0.0;
  double _totalDue = 0.0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  List<SaleModel> _recentSales = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String get _timeBasedGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'শুভ সকাল!';
    if (hour < 17) return 'শুভ অপরাহ্ন!';
    return 'শুভ সন্ধ্যা!';
  }

  String get _formattedCurrentDate {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM yyyy').format(now);
  }

  double get _cashInHand {
    final net = _todaySales - _todayExpenses;
    return net > 0 ? net : 0.0;
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
        _outOfStockCount = outCount;
        _recentSales = sales.take(5).toList();
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
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
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
                        prefixIcon: Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'বিবরণ প্রদান করুন' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'টাকার পরিমাণ (৳) *',
                        prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.primaryGreen),
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
                        prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.primaryGreen),
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
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                        child: isSubmitting
                            ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                            : const Text('খরচ সংরক্ষণ করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
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
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text('নোটিফিকেশন সেন্টার'),
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
                leading: Icon(Icons.mark_email_unread_rounded, color: AppTheme.primaryGreen),
                title: Text('গ্রাহকদের বকেয়া তাগাদা'),
                subtitle: Text('আজকের ৩টি বকেয়া তাগাদা অনুস্মারক'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বন্ধ করুন'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.primaryGreen,
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : CustomScrollView(
                slivers: [
                  // SECTION 1: HEADER
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                                      onPressed: () => Scaffold.of(context).openDrawer(),
                                      tooltip: 'মেনু খুলুন',
                                    ),
                                    const SizedBox(width: 4),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _timeBasedGreeting,
                                          style: const TextStyle(
                                            color: AppTheme.accentGold,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'ADOT Organic Store',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formattedCurrentDate,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.search_rounded, size: 24, color: Colors.white),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const UniversalSearchScreen(),
                                          ),
                                        );
                                      },
                                      tooltip: 'খুঁজুন',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.notifications_outlined, size: 24, color: Colors.white),
                                      onPressed: _showNotificationCenter,
                                      tooltip: 'নোটিফিকেশন',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // SECTION 2: SUMMARY CARDS
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        StatCard(
                          title: "আজকের বিক্রি",
                          value: "৳ ${_todaySales.toStringAsFixed(0)}",
                          subtitle: "আজকের মোট বেচাকেনা",
                          icon: Icons.point_of_sale_rounded,
                          iconBgColor: const Color(0xFFE6F4EA),
                          iconColor: AppTheme.primaryGreen,
                        ),
                        StatCard(
                          title: "আজকের খরচ",
                          value: "৳ ${_todayExpenses.toStringAsFixed(0)}",
                          subtitle: "দৈনন্দিন বায়",
                          icon: Icons.account_balance_wallet_rounded,
                          iconBgColor: const Color(0xFFFCE8E6),
                          iconColor: AppTheme.errorRed,
                        ),
                        StatCard(
                          title: "আজকের নিট লাভ",
                          value: "৳ ${_todayNetProfit.toStringAsFixed(0)}",
                          subtitle: _todayNetProfit >= 0 ? "আজকের অর্জিত নিট লাভ" : "আজকের লোকসান/ক্ষতি",
                          icon: Icons.monetization_on_rounded,
                          iconBgColor: _todayNetProfit >= 0 ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                          iconColor: _todayNetProfit >= 0 ? AppTheme.primaryGreen : AppTheme.errorRed,
                        ),
                        StatCard(
                          title: "হাতে নগদ ক্যাশ",
                          value: "৳ ${_cashInHand.toStringAsFixed(0)}",
                          subtitle: "আজকের নগদ জমা",
                          icon: Icons.payments_rounded,
                          iconBgColor: AppTheme.lightGreenBg,
                          iconColor: AppTheme.primaryGreen,
                        ),
                        StatCard(
                          title: "মোট বাকি/বকেয়া",
                          value: "৳ ${_totalDue.toStringAsFixed(0)}",
                          subtitle: "গ্রাহকদের বকেয়া হিসেব",
                          icon: Icons.pending_actions_rounded,
                          iconBgColor: const Color(0xFFFEF7E0),
                          iconColor: AppTheme.warningOrange,
                        ),
                      ],
                    ),
                  ),

                  // SECTION 3: QUICK ACTIONS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('কুইক অ্যাকশন (Quick Actions)'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  title: 'নতুন বিক্রি',
                                  icon: Icons.shopping_cart_outlined,
                                  color: AppTheme.primaryGreen,
                                  onTap: widget.onNavigateToPOS,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  title: 'পণ্য যোগ',
                                  icon: Icons.add_box_outlined,
                                  color: const Color(0xFF2563EB),
                                  onTap: _showAddProductModal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  title: 'নতুন ক্রয়',
                                  icon: Icons.move_to_inbox_outlined,
                                  color: const Color(0xFF7C3AED),
                                  onTap: () => CustomSnackBar.showInfo(context, 'নতুন ক্রয় মডিউল শীঘ্রই আসছে!'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  title: 'খরচ যোগ',
                                  icon: Icons.receipt_long_outlined,
                                  color: AppTheme.errorRed,
                                  onTap: _showAddExpenseModal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // SECTION 4: ALERTS SECTION
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('জরুরী অ্যালার্ট (Important Alerts)'),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const LowStockScreen()),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 22),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'কম স্টকের পণ্য: $_lowStockCount টি পণ্যে স্টক কম',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const Text(
                                            'দেখুন >',
                                            style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  InkWell(
                                    onTap: () => CustomSnackBar.showInfo(context, 'কর্মচারীদের বকেয়া বেতন প্রক্রিয়াধীন'),
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.badge_outlined, color: AppTheme.warningOrange, size: 22),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'কর্মচারী বেতন: ১ জনের বেতন বকেয়া রয়েছে',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          Text(
                                            'বিস্তারিত >',
                                            style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  InkWell(
                                    onTap: () => CustomSnackBar.showInfo(context, 'গ্রাহকদের বকেয়া তাগাদা অনুস্মারক পাঠানো হয়েছে'),
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryGreen, size: 22),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'বকেয়া তাগাদা: গ্রাহকদের ৩টি বকেয়া তাগাদা অনুস্মারক',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          Text(
                                            'তাগাদা দিন >',
                                            style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // SECTION 5: RECENT SALES (Collapsible Summary Card)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Card(
                        child: Column(
                          children: [
                            // Collapsed Header Tap Area
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isRecentSalesExpanded = !_isRecentSalesExpanded;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.lightGreenBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.shopping_cart_rounded, color: AppTheme.primaryGreen, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '🛒 Recent Sales (সাম্প্রতিক বিক্রি)',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '৳ ${_todaySales.toStringAsFixed(0)} • ${_recentSales.length}টি বিক্রি আজ',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    AnimatedRotation(
                                      turns: _isRecentSalesExpanded ? 0.5 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppTheme.primaryGreen,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expandable Sales List & View All Sales Button
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Column(
                                children: [
                                  const Divider(height: 1),
                                  _recentSales.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Text(
                                            'এখনও কোন বিক্রি রেকর্ড পাওয়া যায়নি',
                                            style: TextStyle(color: AppTheme.textMuted),
                                          ),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _recentSales.length,
                                          itemBuilder: (context, index) {
                                            final sale = _recentSales[index];
                                            final String timeStr = sale.createdAt != null
                                                ? DateFormat('h:mm a').format(sale.createdAt!)
                                                : 'আজ';

                                            return Container(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: AppTheme.cardBorderColor, width: 0.5)),
                                              ),
                                              child: ListTile(
                                                dense: true,
                                                leading: CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                                  child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryGreen, size: 18),
                                                ),
                                                title: Text(
                                                  sale.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                subtitle: Text(
                                                  'গ্রাহক: ${sale.customerName.isEmpty ? "নগদ বিক্রি" : sale.customerName} • $timeStr',
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                                trailing: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '৳ ${sale.totalPrice.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppTheme.primaryGreen,
                                                      ),
                                                    ),
                                                    if (sale.dueAmount > 0)
                                                      Text(
                                                        'বকেয়া: ৳ ${sale.dueAmount.toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppTheme.errorRed,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                  Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const ReportScreen()),
                                          );
                                        },
                                        icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.primaryGreen),
                                        label: const Text(
                                          'সকল বিক্রি দেখুন (View All Sales) >',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              crossFadeState: _isRecentSalesExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // SECTION 6, 7 & 8: SUMMARY SECTIONS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // SECTION 6: Inventory Summary Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ইনভেন্টরি স্টক সারাংশ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryGreen),
                                      ),
                                      Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen, size: 20),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildSummaryItem('মোট পণ্য', '$_totalProducts টি', AppTheme.primaryGreen),
                                      _buildSummaryItem('কম স্টক', '$_lowStockCount টি', AppTheme.warningOrange),
                                      _buildSummaryItem('স্টক শেষ', '$_outOfStockCount টি', AppTheme.errorRed),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // SECTION 7: Employee Summary Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'কর্মচারী বেতন সারাংশ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryGreen),
                                      ),
                                      Icon(Icons.badge_outlined, color: AppTheme.primaryGreen, size: 20),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildSummaryItem('মোট কর্মচারী', '৪ জন', AppTheme.primaryGreen),
                                      _buildSummaryItem('পরিশোধিত বেতন', '৳ ৪৫,০০০', AppTheme.primaryGreen),
                                      _buildSummaryItem('বকেয়া বেতন', '৳ ৮,০০০', AppTheme.errorRed),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // SECTION 8: Expense Summary Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'খরচ সারাংশ (Expense Summary)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryGreen),
                                      ),
                                      Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryGreen, size: 20),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildSummaryItem('আজকের খরচ', '৳ ${_todayExpenses.toStringAsFixed(0)}', AppTheme.errorRed),
                                      _buildSummaryItem('চলতি মাসের খরচ', '৳ ${(_todayExpenses * 18).toStringAsFixed(0)}', AppTheme.warningOrange),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
