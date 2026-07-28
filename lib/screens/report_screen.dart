import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/pdf_report_service.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final GlobalKey _pdfReportKey = GlobalKey();

  bool _isLoading = true;
  bool _isExportingPdf = false;

  double _totalSales = 0.0;
  double _totalExpenses = 0.0;
  double _totalDue = 0.0;
  int _salesCount = 0;
  int _expensesCount = 0;
  List<SaleModel> _salesList = [];
  List<ExpenseModel> _expensesList = [];

  // Dedicated PDF Export Render State
  String _exportPeriodTitle = 'এই মাস';
  double _exportSalesSum = 0.0;
  double _exportExpensesSum = 0.0;
  double _exportDueSum = 0.0;
  List<SaleModel> _exportSalesList = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      final expenses = await _supabaseService.fetchExpenses();

      double salesSum = 0.0;
      double dueSum = 0.0;
      for (var s in sales) {
        salesSum += s.totalPrice;
        dueSum += s.dueAmount;
      }

      double expensesSum = 0.0;
      for (var e in expenses) {
        expensesSum += e.amount;
      }

      if (!mounted) return;
      setState(() {
        _salesList = sales;
        _expensesList = expenses;
        _totalSales = salesSum;
        _totalExpenses = expensesSum;
        _totalDue = dueSum;
        _salesCount = sales.length;
        _expensesCount = expenses.length;
        _exportSalesSum = salesSum;
        _exportExpensesSum = expensesSum;
        _exportDueSum = dueSum;
        _exportSalesList = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'রিপোর্ট ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  void _showDateRangeFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom +
                  MediaQuery.of(modalContext).padding.bottom +
                  16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'রিপোর্ট সময়কাল নির্বাচন করুন',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.today_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('আজ (Today)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('আজকের দিনের বিক্রি ও খরচের হিসাব'),
                  onTap: () async {
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _processAndGenerateReport('আজ');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_view_week_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('এই সপ্তাহ (This Week)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('চলতি সপ্তাহের মোট হিসাব'),
                  onTap: () async {
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _processAndGenerateReport('এই সপ্তাহ');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryGreen),
                  ),
                  title: const Text('এই মাস (This Month)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('চলতি মাসের সার্বিক হিসাব'),
                  onTap: () async {
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _processAndGenerateReport('এই মাস');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processAndGenerateReport(String periodTitle) async {
    if (_isExportingPdf) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E4F3E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(minutes: 2),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'PDF রিপোর্ট তৈরি হচ্ছে ($periodTitle), অনুগ্রহ করে অপেক্ষা করুন...',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    setState(() => _isExportingPdf = true);

    // Allow UI frame pass so toast renders instantly on screen
    await WidgetsBinding.instance.endOfFrame;

    try {
      final now = DateTime.now();
      List<SaleModel> filteredSales = [];
      double filteredSalesSum = 0.0;
      double filteredDueSum = 0.0;
      double filteredExpensesSum = 0.0;

      if (periodTitle == 'আজ') {
        filteredSales = _salesList.where((s) {
          if (s.createdAt == null) return false;
          return s.createdAt!.year == now.year &&
              s.createdAt!.month == now.month &&
              s.createdAt!.day == now.day;
        }).toList();

        for (var e in _expensesList) {
          if (e.createdAt != null &&
              e.createdAt!.year == now.year &&
              e.createdAt!.month == now.month &&
              e.createdAt!.day == now.day) {
            filteredExpensesSum += e.amount;
          }
        }
      } else if (periodTitle == 'এই সপ্তাহ') {
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        filteredSales = _salesList.where((s) {
          if (s.createdAt == null) return false;
          return s.createdAt!.isAfter(startOfWeek) || s.createdAt!.isAtSameMomentAs(startOfWeek);
        }).toList();

        for (var e in _expensesList) {
          if (e.createdAt != null && (e.createdAt!.isAfter(startOfWeek) || e.createdAt!.isAtSameMomentAs(startOfWeek))) {
            filteredExpensesSum += e.amount;
          }
        }
      } else {
        // 'এই মাস'
        filteredSales = _salesList.where((s) {
          if (s.createdAt == null) return false;
          return s.createdAt!.year == now.year && s.createdAt!.month == now.month;
        }).toList();

        for (var e in _expensesList) {
          if (e.createdAt != null && e.createdAt!.year == now.year && e.createdAt!.month == now.month) {
            filteredExpensesSum += e.amount;
          }
        }
      }

      for (var s in filteredSales) {
        filteredSalesSum += s.totalPrice;
        filteredDueSum += s.dueAmount;
      }

      // Update Mounted Export Widget Render Data
      setState(() {
        _exportPeriodTitle = periodTitle;
        _exportSalesSum = filteredSalesSum;
        _exportExpensesSum = filteredExpensesSum;
        _exportDueSum = filteredDueSum;
        _exportSalesList = filteredSales;
      });

      // Wait for frame paint completion pass
      await WidgetsBinding.instance.endOfFrame;

      // Safely capture boundary from real mounted render tree
      final imageBytes = await PdfReportService.captureReportSafely(_pdfReportKey);

      if (imageBytes != null) {
        await PdfReportService.exportReportAsPdf(imageBytes);
      } else {
        if (!mounted) return;
        CustomSnackBar.showError(context, 'PDF ইমেজ ক্যাপচার করতে ব্যর্থ হয়েছে।');
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'PDF তৈরি করতে ব্যর্থ হয়েছে: $e');
    } finally {
      if (mounted) {
        messenger.clearSnackBars();
        setState(() => _isExportingPdf = false);
      }
    }
  }

  double get _netProfit => _totalSales - _totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('সেলস ও হিসাব রিপোর্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReportData,
            tooltip: 'রিফ্রেশ',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Mounted Offscreen Printable Widget in Active Render Tree
            Positioned(
              left: -9999,
              top: -9999,
              child: RepaintBoundary(
                key: _pdfReportKey,
                child: PdfReportViewWidget(
                  title: 'ADOT Organic Store',
                  dateRange: _exportPeriodTitle,
                  currentDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  totalSales: _exportSalesSum,
                  totalExpenses: _exportExpensesSum,
                  netProfit: _exportSalesSum - _exportExpensesSum,
                  totalDue: _exportDueSum,
                  salesList: _exportSalesList.take(25).map((sale) => {
                    'product_name': sale.productName,
                    'quantity': sale.displayQuantityWithUnit,
                    'customer_name': sale.customerName.isEmpty ? 'নগদ' : sale.customerName,
                    'total_price': sale.totalPrice.toStringAsFixed(0),
                    'due_amount': sale.dueAmount.toStringAsFixed(0),
                  }).toList(),
                ),
              ),
            ),

            // Main UI
            _isLoading
                ? const Center(
                    child: SpinKitFadingCube(
                      color: AppTheme.primaryGreen,
                      size: 40.0,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReportData,
                    color: AppTheme.primaryGreen,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // PDF Export Launcher Card
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
                                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'সামগ্রিক হিসাব ও খাতা রিপোর্ট',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'সময়কাল ভিত্তিক আয়-ব্যয় ও লাভ-ক্ষতির স্টেটমেন্ট',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isExportingPdf ? null : _showDateRangeFilterDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: AppTheme.darkGreen,
                                ),
                                icon: _isExportingPdf
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.darkGreen),
                                      )
                                    : const Icon(Icons.download_rounded, size: 18),
                                label: const Text('PDF এক্সপোর্ট'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Financial Overview Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildReportCard(
                                title: 'সর্বমোট বিক্রি',
                                value: '৳ ${_totalSales.toStringAsFixed(0)}',
                                subtitle: 'মোট $_salesCountটি অর্ডার',
                                icon: Icons.trending_up_rounded,
                                color: AppTheme.primaryGreen,
                                bgColor: const Color(0xFFE6F4EA),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildReportCard(
                                title: 'সর্বমোট খরচ',
                                value: '৳ ${_totalExpenses.toStringAsFixed(0)}',
                                subtitle: 'মোট $_expensesCountটি বায়',
                                icon: Icons.trending_down_rounded,
                                color: AppTheme.errorRed,
                                bgColor: const Color(0xFFFCE8E6),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _buildReportCard(
                                title: 'নিট লাভ / ব্যালেন্স',
                                value: '৳ ${_netProfit.toStringAsFixed(0)}',
                                subtitle: _netProfit >= 0 ? 'পজিটিভ ক্যাশফ্লো' : 'নেগেটিভ ক্যাশফ্লো',
                                icon: Icons.account_balance_rounded,
                                color: _netProfit >= 0 ? AppTheme.primaryGreen : AppTheme.errorRed,
                                bgColor: _netProfit >= 0 ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildReportCard(
                                title: 'মোট বকেয়া/বাকি',
                                value: '৳ ${_totalDue.toStringAsFixed(0)}',
                                subtitle: 'প্রাপ্তব্য পাওনা',
                                icon: Icons.pending_actions_rounded,
                                color: AppTheme.warningOrange,
                                bgColor: const Color(0xFFFEF7E0),
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
    );
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
