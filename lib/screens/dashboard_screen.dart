import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/speed_dial_fab.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'universal_search_screen.dart';
import 'add_product_screen.dart';

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
  final currencyFormat =
      NumberFormat.currency(symbol: '৳ ', decimalDigits: 2, locale: 'bn');

  bool _isLoading = true;
  double _todaySales = 0.0;
  double _todayExpenses = 0.0;
  double _totalDue = 0.0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  List<SaleModel> _recentSales = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _supabaseService.fetchDashboardStats();
      final sales = await _supabaseService.fetchSales();

      if (!mounted) return;
      setState(() {
        _todaySales = stats['todaySales'] ?? 0.0;
        _todayExpenses = stats['todayExpenses'] ?? 0.0;
        _totalDue = stats['totalDue'] ?? 0.0;
        _totalProducts = stats['totalProducts'] ?? 0;
        _lowStockCount = stats['lowStockCount'] ?? 0;
        _recentSales = sales.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(
          context, 'ড্যাশবোর্ড ডাটা লোড করতে সমস্যা হয়েছে: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      floatingActionButton: SpeedDialFab(
        onNewSale: widget.onNavigateToPOS,
        onAddProduct: _showAddProductModal,
        onAddExpense: _showAddExpenseModal,
      ),
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
                  // Header Banner
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'স্বাগতম!',
                                        style: TextStyle(
                                          color: AppTheme.accentGold,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'ADOT | আদত ড্যাশবোর্ড',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.search,
                                    size: 26, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const UniversalSearchScreen(),
                                    ),
                                  );
                                },
                                tooltip: 'খুঁজুন',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),

                  // Metrics Cards Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
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
                          title: "মোট বাকি/বকেয়া",
                          value: "৳ ${_totalDue.toStringAsFixed(0)}",
                          subtitle: "গ্রাহকদের বকেয়া হিসেব",
                          icon: Icons.pending_actions_rounded,
                          iconBgColor: const Color(0xFFFEF7E0),
                          iconColor: AppTheme.warningOrange,
                        ),
                        StatCard(
                          title: "মোট পণ্য সংখ্যা",
                          value: "$_totalProducts টি",
                          subtitle: _lowStockCount > 0
                              ? "$_lowStockCount টি পণ্যে কম স্টক"
                              : "স্টক স্বাভাবিক",
                          icon: Icons.inventory_2_rounded,
                          iconBgColor: const Color(0xFFF3F7E5),
                          iconColor: const Color(0xFF7A8921),
                          onTap: widget.onNavigateToInventory,
                        ),
                      ],
                    ),
                  ),

                  // Quick POS Launcher Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.accentGold.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_shopping_cart_rounded,
                                  color: AppTheme.accentGold, size: 28),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'নতুন বিক্রি তৈরি করুন',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'দ্রুত বিল তৈরি ও স্টক আপডেট',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: widget.onNavigateToPOS,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGold,
                                foregroundColor: AppTheme.darkGreen,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              child: const Text('পস শুরু করুন'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Recent Sales Header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'সাম্প্রতিক বিক্রি',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Icon(Icons.history_rounded,
                              color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),

                  // Recent Sales List
                  _recentSales.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'এখনও কোন বিক্রি রেকর্ড পাওয়া যায়নি',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final sale = _recentSales[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 4.0),
                                child: Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryGreen
                                          .withValues(alpha: 0.1),
                                      child: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: AppTheme.primaryGreen),
                                    ),
                                    title: Text(
                                      sale.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'গ্রাহক: ${sale.customerName.isEmpty ? "নগদ বিক্রি" : sale.customerName} • পরিমাণ: ${sale.quantity}টি',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '৳ ${sale.totalPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                        if (sale.dueAmount > 0)
                                          Text(
                                            'বকেয়া: ৳ ${sale.dueAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.errorRed,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _recentSales.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
      ),
    );
  }
}
