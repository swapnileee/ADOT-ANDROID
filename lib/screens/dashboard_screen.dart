import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/shop_info_service.dart';
import '../services/refresh_signal.dart';
import '../widgets/custom_snackbar.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'universal_search_screen.dart';
import 'add_product_screen.dart';
import 'low_stock_screen.dart';
import 'dues_screen.dart';
import 'stock_in_screen.dart';
import 'staff_management_screen.dart';
import 'notification_center_screen.dart';
import 'expenses_screen.dart';
import 'net_profit_breakdown_screen.dart';
import 'cash_in_hand_breakdown_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToPOS;
  final VoidCallback onNavigateToInventory;
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToExpenses;
  final VoidCallback? onNavigateToCashInHand;
  final VoidCallback? onNavigateToNetProfit;
  final Function(int)? onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPOS,
    required this.onNavigateToInventory,
    this.onNavigateToOrders,
    this.onNavigateToExpenses,
    this.onNavigateToCashInHand,
    this.onNavigateToNetProfit,
    this.onNavigateToTab,
  });

  // Brand Palette Constants
  static const Color primaryGreen = Color(0xFF1E4632);
  static const Color cardGreen = Color(0xFF163E2B);
  static const Color bgGray = Color(0xFFF4F6F5);
  static const Color textDark = Color(0xFF1F2937);

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  double _todaySales = 0.0;
  double _todayPaidSales = 0.0;
  double _todayDueCollected = 0.0;
  double _todayExpenses = 0.0;
  double _todayNetProfit = 0.0;
  double _yesterdayExpenses = 0.0;
  double _yesterdayNetProfit = 0.0;
  String _lastUpdatedTime = '';
  double _totalDue = 0.0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  int _todayOrderCount = 0;
  int _unpaidStaffCount = 0;
  final List<SaleModel> _recentSales = [];
  List<SaleModel> _allSales = [];

  // Interactive Filter & Notification Badge State
  String _selectedSalesFilter = 'আজ';
  int _unreadNotificationCount = 3;

  // Yesterday's sales fetched directly from Supabase with UTC-converted BD bounds
  double _yesterdaySales = 0.0;
  DateTime _lastLoadedDate = DateTime.now();
  DateTime _lastFetchTime = DateTime.now(); // Guards resumed auto-refresh
  // Tracks the previous lifecycle state to distinguish true background resume
  // from transient overlays (notification panel, volume popup, etc.)
  AppLifecycleState? _previousLifecycleState;

  // Midnight Auto-Refresh Timer State
  Timer? _midnightTimer;
  DateTime _lastActiveBDDate = DateTime.now().toUtc().add(const Duration(hours: 6));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLoadedDate = DateTime.now();
    _startMidnightTimer();
    RefreshSignal().addListener(_onRefreshSignal);
    _loadDashboardData();
  }

  void _onRefreshSignal() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  void refreshData() {
    _loadDashboardData();
  }

  void _startMidnightTimer() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      final DateTime currentBD = DateTime.now().toUtc().add(const Duration(hours: 6));
      final bool isSameDay = currentBD.year == _lastActiveBDDate.year &&
                       currentBD.month == _lastActiveBDDate.month &&
                       currentBD.day == _lastActiveBDDate.day;
      if (!isSameDay) {
        _lastActiveBDDate = currentBD;
        _resetTodayState();
        _loadDashboardData(); // Trigger fresh fetch on midnight date change!
      }
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    RefreshSignal().removeListener(_onRefreshSignal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only refresh if we truly returned from the background (paused).
      // Notification panel / volume overlay: inactive → resumed (NO paused step)
      // Real app switch:                      paused  → resumed
      // This single check eliminates all spurious notification-panel flickers.
      if (_previousLifecycleState == AppLifecycleState.paused) {
        final now = DateTime.now();
        final dateChanged = now.day != _lastLoadedDate.day ||
            now.month != _lastLoadedDate.month ||
            now.year != _lastLoadedDate.year;
        final dataStale = now.difference(_lastFetchTime).inMinutes >= 5;

        if (dateChanged) {
          _resetTodayState();
          _loadDashboardData();
        } else if (dataStale) {
          _loadDashboardData();
        }
        // Fresh data + same day: instant resume, no reload
      }
    }
    _previousLifecycleState = state;
  }

  void _resetTodayState() {
    if (!mounted) return;
    setState(() {
      _todaySales = 0.0;
      _todayPaidSales = 0.0;
      _todayDueCollected = 0.0;
      _todayOrderCount = 0;
      _todayExpenses = 0.0;
      _todayNetProfit = 0.0;
    });
  }

  String get _formattedCurrentDate {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM yyyy').format(now);
  }

  double get _cashInHand {
    final net = (_todayPaidSales + _todayDueCollected) - _todayExpenses;
    return net > 0 ? net : 0.0;
  }

  double get _displayedSalesAmount {
    // For 'আজ': use the direct Supabase-queried value (UTC-aligned BD midnight bounds).
    // This is the single source of truth — same value shown in the summary strip.
    if (_selectedSalesFilter == 'আজ') return _todaySales;

    final now = DateTime.now();
    DateTime startCurrent;
    final DateTime endCurrent = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (_selectedSalesFilter) {
      case 'এই সপ্তাহ':
        startCurrent = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case 'এই মাস':
        startCurrent = DateTime(now.year, now.month, 1);
        break;
      case 'এই বছর':
      default:
        startCurrent = DateTime(now.year, 1, 1);
        break;
    }

    double total = 0.0;
    for (var sale in _allSales) {
      if (sale.createdAt != null) {
        final saleDate = sale.createdAt!.toLocal();
        if (!saleDate.isBefore(startCurrent) && !saleDate.isAfter(endCurrent)) {
          total += sale.totalPrice;
        }
      }
    }
    return total;
  }

  double get _displayedPreviousSalesAmount {
    // For 'আজ' filter: use the real Supabase-fetched yesterday total (UTC-aligned BD bounds)
    if (_selectedSalesFilter == 'আজ') return _yesterdaySales;

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
      default:
        final startCurrent = DateTime(now.year, 1, 1);
        startPrev = DateTime(now.year - 1, 1, 1);
        endPrev = startCurrent.subtract(const Duration(milliseconds: 1));
        break;
    }

    double total = 0.0;
    for (var sale in _allSales) {
      if (sale.createdAt != null) {
        final saleDate = sale.createdAt!.toLocal();
        if (!saleDate.isBefore(startPrev) && !saleDate.isAfter(endPrev)) {
          total += sale.totalPrice;
        }
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

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadDashboardData() async {
    final nowCheck = DateTime.now();
    if (nowCheck.day != _lastLoadedDate.day || nowCheck.month != _lastLoadedDate.month || nowCheck.year != _lastLoadedDate.year) {
      _resetTodayState();
    }
    _lastLoadedDate = nowCheck;

    if (_recentSales.isEmpty && _allSales.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      // 1. Direct date-bounded Supabase queries for BD local midnight boundaries
      final todayStats = await _supabaseService.fetchTodayOrderStats();
      final realTodaySales = (todayStats['totalSales'] as double?) ?? 0.0;
      final realTodayOrderCount = (todayStats['orderCount'] as int?) ?? 0;
      final realYesterdaySales = await _supabaseService.fetchYesterdayOrderTotal();

      // 2. Fetch supporting data (expenses, products, all sales for display list, due collections, staff, salary payments)
      final sales = await _supabaseService.fetchSales();
      final products = await _supabaseService.fetchProducts();
      final expenses = await _supabaseService.fetchExpenses();
      final dueCollections = await _supabaseService.fetchDueCollections();
      final staffList = await _supabaseService.fetchStaff();
      final salaryPayments = await _supabaseService.fetchSalaryPayments();

      int unpaidStaffCalcCount = 0;
      final nowStaff = DateTime.now();
      for (var staff in staffList) {
        if (!staff.isActive) continue;

        if (staff.joinDate.year > nowStaff.year ||
            (staff.joinDate.year == nowStaff.year && staff.joinDate.month >= nowStaff.month)) {
          continue;
        }

        bool hasUnpaid = false;
        DateTime current = DateTime(staff.joinDate.year, staff.joinDate.month, 1);
        final DateTime limit = DateTime(nowStaff.year, nowStaff.month, 1);

        while (!current.isAfter(limit)) {
          final monthStr = DateFormat('MMMM yyyy').format(current);
          final isPaid = salaryPayments.any((p) =>
              p.staffId.toString() == staff.id.toString() &&
              p.monthYear.trim().toLowerCase() == monthStr.trim().toLowerCase());
          if (!isPaid) {
            hasUnpaid = true;
            break;
          }
          current = DateTime(current.year, current.month + 1, 1);
        }

        if (hasUnpaid) {
          unpaidStaffCalcCount++;
        }
      }

      int outCount = 0;
      for (var p in products) {
        if (p.totalStock <= 0) outCount++;
      }

      // Calculate Strict Local Calendar Day Boundaries (00:00:00 to 23:59:59)
      final now = DateTime.now();
      final localStartOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final localEndOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final startOfYesterday = localStartOfDay.subtract(const Duration(days: 1));

      // Direct sales paid amount today from sales list
      double computedTodayPaidSales = 0.0;
      for (var sale in sales) {
        if (sale.createdAt != null) {
          final saleDate = sale.createdAt!.toLocal();
          if (!saleDate.isBefore(localStartOfDay) && !saleDate.isAfter(localEndOfDay)) {
            computedTodayPaidSales += sale.paidAmount;
          }
        }
      }

      // Due collections / repayments collected today
      double computedTodayDueCollected = 0.0;
      for (var col in dueCollections) {
        final colDate = col.createdAt.toLocal();
        if (!colDate.isBefore(localStartOfDay) && !colDate.isAfter(localEndOfDay)) {
          computedTodayDueCollected += col.amount;
        }
      }

      // Compute expenses
      double computedTodayExpenses = 0.0;
      double computedYesterdayExpenses = 0.0;
      double computedTotalDue = 0.0;

      for (var exp in expenses) {
        final expDate = (exp.expenseDate ?? exp.createdAt);
        if (expDate != null) {
          final expDateLocal = expDate.toLocal();
          if (!expDateLocal.isBefore(localStartOfDay) && !expDateLocal.isAfter(localEndOfDay)) {
            computedTodayExpenses += exp.amount;
          } else if (!expDateLocal.isBefore(startOfYesterday) && expDateLocal.isBefore(localStartOfDay)) {
            computedYesterdayExpenses += exp.amount;
          }
        }
      }

      final realTodayCogs = (todayStats['totalCogs'] as double?) ?? 0.0;

      // Build map of product buying prices for COGS calculation
      final productBuyingPrices = <String, double>{};
      for (var p in products) {
        productBuyingPrices[p.name.trim().toLowerCase()] = p.buyingPrice;
        if (p.id.toString().isNotEmpty) {
          productBuyingPrices[p.id.toString()] = p.buyingPrice;
        }
      }

      double computedTodayCogs = realTodayCogs;
      double computedYesterdayCogs = 0.0;

      for (var sale in sales) {
        if (sale.createdAt != null) {
          final saleDate = sale.createdAt!.toLocal();
          final key = sale.productName.trim().toLowerCase();
          final unitCost = productBuyingPrices[key] ?? (sale.totalPrice * 0.70);
          final saleCogs = sale.quantity * unitCost;

          if (!saleDate.isBefore(localStartOfDay)) {
            if (computedTodayCogs == 0.0) {
              computedTodayCogs += saleCogs;
            }
          } else if (!saleDate.isBefore(startOfYesterday) && saleDate.isBefore(localStartOfDay)) {
            computedYesterdayCogs += saleCogs;
          }
        }
        if (sale.dueAmount > 0) computedTotalDue += sale.dueAmount;
      }

      final finalTodaySales = realTodaySales;
      final finalTodayOrderCount = realTodayOrderCount;

      final netProfitToday = finalTodaySales - computedTodayCogs - computedTodayExpenses;
      final netProfitYesterday = realYesterdaySales - computedYesterdayCogs - computedYesterdayExpenses;
      final updatedTimeText = DateFormat('hh:mm a').format(now);

      if (!mounted) return;
      setState(() {
        _todaySales = finalTodaySales;
        _todayPaidSales = (todayStats['paidSales'] as double? ?? 0.0) > 0
            ? (todayStats['paidSales'] as double)
            : computedTodayPaidSales;
        _todayDueCollected = computedTodayDueCollected;
        _todayExpenses = computedTodayExpenses;
        _todayNetProfit = netProfitToday;
        _yesterdayExpenses = computedYesterdayExpenses;
        _yesterdayNetProfit = netProfitYesterday;
        _lastUpdatedTime = updatedTimeText;
        _totalDue = computedTotalDue;
        _totalProducts = products.length;
        _lowStockCount = products.where((p) => p.isLowStock).length;
        _todayOrderCount = finalTodayOrderCount;
        _outOfStockCount = outCount;
        _unpaidStaffCount = unpaidStaffCalcCount;
        _allSales = sales;
        _recentSales.clear();
        _recentSales.addAll(sales.take(5));
        if (_dashboardNotifications.isNotEmpty) {
          _unreadNotificationCount = _dashboardNotifications.where((n) => !n.isRead).length;
        } else {
          _unreadNotificationCount = _lowStockCount > 0 ? 3 : 1;
        }
        // Store yesterday's sales for comparison in the main card
        _yesterdaySales = realYesterdaySales;
        _isLoading = false;
        _lastFetchTime = DateTime.now(); // Stamp successful fetch time
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
                                  RefreshSignal().notifyDataChanged();
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

  List<AppNotification> _dashboardNotifications = [];

  void _initDashboardNotifications() {
    if (_dashboardNotifications.isEmpty) {
      _dashboardNotifications = [
        AppNotification(
          id: '1',
          title: '$_lowStockCount টি পণ্যে কম স্টক রয়েছে',
          message: 'জরুরি স্টক রি-অর্ডার করার অনুরোধ করা হচ্ছে',
          timeAgo: '২ মিনিট আগে',
          type: NotificationType.urgent,
          actionText: 'স্টক দেখুন',
          icon: Icons.warning_amber_rounded,
          onAction: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LowStockScreen()));
          },
        ),
        AppNotification(
          id: '2',
          title: 'কর্মচারীদের বকেয়া বেতন',
          message: 'চলতি মাসের ১ জনের বেতন প্রক্রিয়াধীন রয়েছে',
          timeAgo: '১০ মিনিট আগে',
          type: NotificationType.pending,
          actionText: 'বেতন দিন',
          icon: Icons.schedule_rounded,
          onAction: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
          },
        ),
        AppNotification(
          id: '3',
          title: 'গ্রাহকদের বকেয়া তাগাদা',
          message: 'আজকের ৩টি বকেয়া তাগাদা অনুস্মারক তৈরি হয়েছে',
          timeAgo: '২৫ মিনিট আগে',
          type: NotificationType.urgent,
          actionText: 'বাকির তালিকা',
          icon: Icons.mark_email_unread_rounded,
          onAction: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DuesScreen()));
          },
        ),
      ];
    }
  }

  Future<void> _showNotificationCenter() async {
    _initDashboardNotifications();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          notifications: _dashboardNotifications,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        if (result is int) {
          _unreadNotificationCount = result;
        } else {
          _unreadNotificationCount = _dashboardNotifications.where((n) => !n.isRead).length;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. TODAY SUMMARY STRIP
                          _buildTodaySummaryStrip(),
                          const SizedBox(height: 12),

                          // 3. MAIN CARDS: TODAY'S SALES
                          _buildMainMetricsCards(),
                          const SizedBox(height: 10.0),

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
                          const SizedBox(height: 120),
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
          ValueListenableBuilder<ShopInfo>(
            valueListenable: ShopInfoService.shopInfoNotifier,
            builder: (context, shopInfo, _) {
              final logoImg = ShopInfoService.buildShopLogoImage(shopInfo.logoPath);
              final hasLogo = logoImg != null;
              return CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white24,
                backgroundImage: logoImg,
                child: hasLogo
                    ? null
                    : const Text(
                        'ADOT',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<ShopInfo>(
                  valueListenable: ShopInfoService.shopInfoNotifier,
                  builder: (context, shopInfo, _) {
                    return Text(
                      shopInfo.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
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
                MaterialPageRoute(
                  builder: (context) => UniversalSearchScreen(
                    initialProducts: _supabaseService.cachedProducts,
                    initialSales: _allSales,
                    initialExpenses: _supabaseService.cachedExpenses,
                  ),
                ),
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

  // 3. MAIN METRICS (GREEN CARD WITH INTERACTIVE FILTER & BACKGROUND ILLUSTRATION)
  Widget _buildMainMetricsCards() {
    final double previous = _displayedPreviousSalesAmount;
    final double current = _displayedSalesAmount;
    final double growth = _displayedGrowthPercentage;
    final bool hasPrevData = previous > 0;
    final bool isPositive = growth >= 0;
    final Color accentColor = isPositive ? Colors.greenAccent : Colors.orangeAccent;
    final IconData arrowIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    const double cardRadius = 22.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: DashboardScreen.cardGreen,
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            // Background Shop Illustration
            Positioned(
              right: 10,
              bottom: 0,
              child: Image.asset(
                'assets/images/shop_illustration.png',
                height: 148,
                fit: BoxFit.contain,
              ),
            ),

            // Foreground Text & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Text('৳ ${current.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (hasPrevData || current > 0) ? accentColor.withValues(alpha: 0.2) : Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            if (hasPrevData || current > 0) ...[
                              Icon(arrowIcon, color: accentColor, size: 12),
                              const SizedBox(width: 2),
                              Text('${isPositive && growth > 0 ? "+" : ""}${growth.abs().toStringAsFixed(0)}%', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ] else ...[
                              const Text('0%', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_displayedComparisonText, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 165,
                    child: Divider(color: Colors.white12),
                  ),
                  Text(_displayedPreviousAmountText, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryMetricsGrid() {
    String profitSubtext;
    if (_yesterdayNetProfit > 0) {
      double diff = ((_todayNetProfit - _yesterdayNetProfit) / _yesterdayNetProfit) * 100;
      String sign = diff >= 0 ? '+' : '';
      profitSubtext = '$sign${diff.toStringAsFixed(0)}% গতকালের তুলনায়';
    } else if (_yesterdayNetProfit == 0) {
      if (_todayNetProfit > 0) {
        profitSubtext = '+১০০% গতকালের তুলনায়';
      } else {
        profitSubtext = 'গতকালের উপাত্ত নেই';
      }
    } else {
      // _yesterdayNetProfit < 0 (yesterday was a loss)
      if (_todayNetProfit >= 0) {
        profitSubtext = 'লোকসান থেকে লাভে';
      } else {
        if (_todayNetProfit > _yesterdayNetProfit) {
          profitSubtext = 'লোকসান কমেছে';
        } else if (_todayNetProfit < _yesterdayNetProfit) {
          profitSubtext = 'লোকসান বেড়েছে';
        } else {
          profitSubtext = 'একই লোকসান';
        }
      }
    }

    String expenseSubtext;
    if (_yesterdayExpenses > 0) {
      double diff = ((_todayExpenses - _yesterdayExpenses) / _yesterdayExpenses) * 100;
      String sign = diff >= 0 ? '+' : '';
      expenseSubtext = '$sign${diff.toStringAsFixed(0)}% গতকালের তুলনায়';
    } else if (_todayExpenses > 0) {
      expenseSubtext = 'আজকের মোট খরচ';
    } else {
      expenseSubtext = 'গতকালের উপাত্ত নেই';
    }

    String cashSubtext = _lastUpdatedTime.isNotEmpty ? 'আপডেট: আজ $_lastUpdatedTime' : 'আপডেট: আজ';

    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _buildSecondaryCard(
          'নিট লাভ',
          '৳ ${_todayNetProfit.toStringAsFixed(0)}',
          profitSubtext,
          Icons.trending_up,
          const Color(0xFF2E7D32),
          onTap: () {
            if (widget.onNavigateToNetProfit != null) {
              widget.onNavigateToNetProfit!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NetProfitBreakdownScreen(
                    onSelectTab: widget.onNavigateToTab,
                  ),
                ),
              ).then((_) => _loadDashboardData());
            }
          },
        ),
        _buildSecondaryCard(
          'মোট খরচ',
          '৳ ${_todayExpenses.toStringAsFixed(0)}',
          expenseSubtext,
          Icons.trending_down,
          const Color(0xFFD32F2F),
          onTap: () {
            if (widget.onNavigateToExpenses != null) {
              widget.onNavigateToExpenses!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExpensesScreen()),
              ).then((_) => _loadDashboardData());
            }
          },
        ),
        _buildSecondaryCard(
          'হাতে নগদ',
          '৳ ${_cashInHand.toStringAsFixed(0)}',
          cashSubtext,
          Icons.account_balance_wallet_outlined,
          const Color(0xFF1565C0),
          onTap: () {
            if (widget.onNavigateToCashInHand != null) {
              widget.onNavigateToCashInHand!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CashInHandBreakdownScreen(
                    onSelectTab: widget.onNavigateToTab,
                  ),
                ),
              ).then((_) => _loadDashboardData());
            }
          },
        ),
        _buildSecondaryCard(
          'বকেয়া আদায়যোগ্য',
          '৳ ${_totalDue.toStringAsFixed(0)}',
          'গ্রাহকের নিকট মোট বকেয়া',
          Icons.receipt_outlined,
          const Color(0xFFEF6C00),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DuesScreen()),
            ).then((_) => _loadDashboardData());
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryCard(
    String title,
    String amount,
    String sub,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(fontSize: 9, color: Colors.black38),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
            _unpaidStaffCount > 0
                ? '$_unpaidStaffCount জনের বেতন বকেয়া আছে'
                : 'সকল কর্মচারীর বেতন পরিশোধিত',
            'বেতন দিন',
            _unpaidStaffCount > 0 ? Colors.orange : Colors.green,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StaffManagementScreen(),
                ),
              ).then((_) => _loadDashboardData());
            },
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
