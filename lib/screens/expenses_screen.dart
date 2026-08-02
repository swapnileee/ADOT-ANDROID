import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../services/refresh_signal.dart';
import '../models/expense_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> with AutomaticKeepAliveClientMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Filter State
  String _selectedDateFilter = 'সব'; // 'সব', 'আজ', 'সপ্তাহ', 'মাস', 'কাস্টম'
  DateTimeRange? _customDateRange;
  String? _selectedCategoryFilter;

  @override
  bool get wantKeepAlive => true;

  // Standard Categories Data Structure
  final List<Map<String, dynamic>> _categoriesData = [
    {
      'name': 'বিদ্যুৎ',
      'icon': Icons.electric_bolt_rounded,
      'color': const Color(0xFFFFB300), // Amber
    },
    {
      'name': 'পরিবহন',
      'icon': Icons.directions_bus_rounded,
      'color': const Color(0xFF1E88E5), // Blue
    },
    {
      'name': 'দোকান ভাড়া',
      'icon': Icons.storefront_rounded,
      'color': const Color(0xFF8E24AA), // Purple
    },
    {
      'name': 'মালামাল',
      'icon': Icons.inventory_2_rounded,
      'color': const Color(0xFF43A047), // Green
    },
    {
      'name': 'বেতন',
      'icon': Icons.badge_rounded,
      'color': const Color(0xFFFB8C00), // Orange
    },
    {
      'name': 'দৈনন্দিন নাস্তা খরচ',
      'icon': Icons.fastfood_rounded,
      'color': const Color(0xFFD81B60), // Pink/Rose
    },
    {
      'name': 'অন্যান্য',
      'icon': Icons.receipt_long_rounded,
      'color': const Color(0xFF546E7A), // Blue Grey
    },
  ];

  @override
  void initState() {
    super.initState();
    RefreshSignal().addListener(_onRefreshSignal);
    _loadExpenses();
  }

  void _onRefreshSignal() {
    if (mounted) {
      _loadExpenses();
    }
  }

  void refreshData() {
    _loadExpenses();
  }

  @override
  void dispose() {
    RefreshSignal().removeListener(_onRefreshSignal);
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses({bool isManual = false}) async {
    if (isManual || _expenses.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final expenses = await _supabaseService.fetchExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
      if (isManual) {
        CustomSnackBar.showSuccess(context, 'খরচের তথ্য আপডেট করা হয়েছে');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'খরচের তালিকা লোড করতে ব্যর্থ: $e');
    }
  }

  String _getCategoryForTitle(ExpenseModel exp) {
    if (exp.category.isNotEmpty && exp.category != 'অন্যান্য') {
      return exp.category;
    }
    final lower = exp.title.toLowerCase();
    if (lower.contains('বিদ্যুৎ') || lower.contains('কারেন্ট') || lower.contains('বিল') || lower.contains('electric')) {
      return 'বিদ্যুৎ';
    }
    if (lower.contains('পরিবহন') || lower.contains('গাড়ি') || (lower.contains('ভাড়া') && !lower.contains('দোকান')) || lower.contains('যাতায়াত') || lower.contains('fuel') || lower.contains('cng') || lower.contains('transport')) {
      return 'পরিবহন';
    }
    if (lower.contains('দোকান') || lower.contains('রেন্ট') || lower.contains('rent')) {
      return 'দোকান ভাড়া';
    }
    if (lower.contains('মাল') || lower.contains('পণ্য') || lower.contains('স্টক') || lower.contains('প্যাকেজিং') || lower.contains('মেমো') || lower.contains('খাতা') || lower.contains('goods') || lower.contains('supply')) {
      return 'মালামাল';
    }
    if (lower.contains('বেতন') || lower.contains('মজুরি') || lower.contains('कर्मচারী') || lower.contains('salary') || lower.contains('staff')) {
      return 'বেতন';
    }
    if (lower.contains('নাস্তা') || lower.contains('খাবার') || lower.contains('টিফিন') || lower.contains('চা') || lower.contains('বিস্কুট') || lower.contains('snack') || lower.contains('tea') || lower.contains('food')) {
      return 'দৈনন্দিন নাস্তা খরচ';
    }
    return 'অন্যান্য';
  }

  Map<String, dynamic> _getCategoryInfo(String categoryName) {
    return _categoriesData.firstWhere(
      (c) => c['name'] == categoryName,
      orElse: () => {
        'name': 'অন্যান্য',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF546E7A),
      },
    );
  }

  List<ExpenseModel> get _dateFilteredExpenses {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return _expenses.where((exp) {
      // 1. Text Search Filter
      if (query.isNotEmpty) {
        final matchesTitle = exp.title.toLowerCase().contains(query);
        final matchesNote = (exp.note ?? '').toLowerCase().contains(query);
        if (!matchesTitle && !matchesNote) return false;
      }

      // 2. Date Filter
      final expDate = (exp.expenseDate ?? exp.createdAt)?.toLocal();
      if (expDate == null) return true;

      switch (_selectedDateFilter) {
        case 'আজ':
          final todayStart = DateTime(now.year, now.month, now.day);
          return expDate.isAfter(todayStart.subtract(const Duration(milliseconds: 1)));
        case 'সপ্তাহ':
          final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          return expDate.isAfter(weekStart.subtract(const Duration(milliseconds: 1)));
        case 'মাস':
          final monthStart = DateTime(now.year, now.month, 1);
          return expDate.isAfter(monthStart.subtract(const Duration(milliseconds: 1)));
        case 'কাস্টম':
          if (_customDateRange != null) {
            final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
            final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
            return expDate.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
                   expDate.isBefore(end.add(const Duration(milliseconds: 1)));
          }
          return true;
        case 'সব':
        default:
          return true;
      }
    }).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    final dateFiltered = _dateFilteredExpenses;
    if (_selectedCategoryFilter == null || _selectedCategoryFilter!.isEmpty) {
      return dateFiltered;
    }
    return dateFiltered.where((exp) {
      final cat = _getCategoryForTitle(exp);
      return cat == _selectedCategoryFilter;
    }).toList();
  }

  double get _filteredTotalExpensesSum {
    return _filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> get _categoryTotals {
    final Map<String, double> totals = {
      'বিদ্যুৎ': 0.0,
      'পরিবহন': 0.0,
      'দোকান ভাড়া': 0.0,
      'মালামাল': 0.0,
      'বেতন': 0.0,
      'দৈনন্দিন নাস্তা খরচ': 0.0,
      'অন্যান্য': 0.0,
    };

    for (var exp in _dateFilteredExpenses) {
      final cat = _getCategoryForTitle(exp);
      totals[cat] = (totals[cat] ?? 0.0) + exp.amount;
    }
    return totals;
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = 'কাস্টম';
      });
    }
  }

  Future<void> _addExpense(String category) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final expense = ExpenseModel(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: category,
        expenseDate: DateTime.now(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      await _supabaseService.addExpense(expense);

      if (!mounted) return;
      CustomSnackBar.showSuccess(context, 'খরচ সফলভাবে সংরক্ষিত হয়েছে!');
      _titleController.clear();
      _amountController.clear();
      _noteController.clear();
      Navigator.pop(context);
      _loadExpenses();
      RefreshSignal().notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'খরচ যোগ করতে ত্রুটি হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmDeleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('খরচ মুছে ফেলুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('আপনি কি নিশ্চিত যে "${expense.title}" খরচের তথ্যটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && expense.id != null) {
      try {
        await _supabaseService.deleteExpense(expense.id);
        if (!mounted) return;
        CustomSnackBar.showSuccess(context, 'খরচ মুছে ফেলা হয়েছে');
        _loadExpenses();
        RefreshSignal().notifyDataChanged();
      } catch (e) {
        if (!mounted) return;
        CustomSnackBar.showError(context, 'খরচ মুছতে ত্রুটি: $e');
      }
    }
  }

  void _showAddExpenseModal() {
    String selectedCategory = 'বিদ্যুৎ';

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
                  key: _formKey,
                  child: SingleChildScrollView(
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
                        
                        // Category Selector Dropdown Chips
                        const Text(
                          'ক্যাটাগরি নির্বাচন করুন:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categoriesData.map((cat) {
                            final isSelected = selectedCategory == cat['name'];
                            final Color color = cat['color'];
                            return ChoiceChip(
                              label: Text(cat['name']),
                              selected: isSelected,
                              avatar: Icon(cat['icon'], size: 16, color: isSelected ? Colors.white : color),
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textDark,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedCategory = cat['name'];
                                    _titleController.text = cat['name'];
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'খরচের বিবরণ/শিরোনাম *',
                            hintText: 'যেমন: দোকান ভাড়া, বিদ্যুৎ বিল, নাস্তা',
                            prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'বিবরণ প্রদান করুন' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'টাকার পরিমাণ (৳) *',
                            hintText: 'যেমন: ৫০০',
                            prefixText: '৳ ',
                            prefixIcon: const Icon(Icons.attach_money_rounded, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'টাকার পরিমাণ প্রদান করুন';
                            if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা প্রদান করুন';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'অতিরিক্ত নোট (ঐচ্ছিক)',
                            hintText: 'যেমন: মেমো #১২৩',
                            prefixIcon: const Icon(Icons.note_alt_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : () => _addExpense(selectedCategory),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                                : const Text(
                                    'খরচ সংরক্ষণ করুন',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final filteredList = _filteredExpenses;
    final categoryTotalsMap = _categoryTotals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: ModalRoute.of(context)?.canPop == true
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                tooltip: 'পেছনে যান',
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'মেনু খুলুন',
              ),
        centerTitle: true,
        title: const Text(
          'দৈনন্দিন খরচ (Expenses)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadExpenses(isManual: true),
            tooltip: 'রিফ্রেশ করুন',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _loadExpenses(isManual: true),
                color: AppTheme.primaryGreen,
                child: Column(
                  children: [
                    // 1. TOP SUMMARY CARD
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'মোট খরচের পরিমাণ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${filteredList.length} টি খরচ রেকর্ড',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '৳ ${_filteredTotalExpensesSum.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. HORIZONTAL FILTER CHIPS BAR & CUSTOM DATE
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('সব'),
                            const SizedBox(width: 8),
                            _buildFilterChip('আজ'),
                            const SizedBox(width: 8),
                            _buildFilterChip('সপ্তাহ'),
                            const SizedBox(width: 8),
                            _buildFilterChip('মাস'),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(
                                _selectedDateFilter == 'কাস্টম' && _customDateRange != null
                                    ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                    : 'কাস্টম তারিখ',
                              ),
                              avatar: const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primaryGreen),
                              selected: _selectedDateFilter == 'কাস্টম',
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: _selectedDateFilter == 'কাস্টম' ? Colors.white : AppTheme.textDark,
                                fontWeight: _selectedDateFilter == 'কাস্টম' ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => _pickCustomDateRange(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. SEARCH BAR & COMPACT ACTION BUTTON ROW
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'বিবরণ বা নোট দিয়ে খরচ খুঁজুন...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen, size: 20),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _showAddExpenseModal,
                                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                label: const Text(
                                  'নতুন খরচ',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B4D2C),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. CATEGORY HIGHLIGHT CARDS BAR
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ক্যাটাগরি ভিত্তিক খরচ',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              if (_selectedCategoryFilter != null)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedCategoryFilter = null),
                                  child: const Text(
                                    'ফিল্টার সরান',
                                    style: TextStyle(fontSize: 11, color: AppTheme.errorRed, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categoriesData.map((cat) {
                                final String catName = cat['name'];
                                final IconData icon = cat['icon'];
                                final Color color = cat['color'];
                                final double spent = categoryTotalsMap[catName] ?? 0.0;
                                final bool isSelected = _selectedCategoryFilter == catName;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryFilter = isSelected ? null : catName;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected ? color : Colors.transparent,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(icon, size: 16, color: color),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              catName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? color : AppTheme.textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '৳ ${spent.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // 5. RECENT EXPENSES LIST
                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.money_off_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'কোন খরচের তথ্য পাওয়া যায়নি',
                                    style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final exp = filteredList[index];
                                final categoryName = _getCategoryForTitle(exp);
                                final categoryInfo = _getCategoryInfo(categoryName);
                                final IconData icon = categoryInfo['icon'];
                                final Color color = categoryInfo['color'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: color.withValues(alpha: 0.12),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            exp.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.textDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            categoryName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (exp.note != null && exp.note!.isNotEmpty)
                                            Text(
                                              'নোট: ${exp.note}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          if (exp.createdAt != null)
                                            Text(
                                              dateFormat.format(exp.createdAt!.toLocal()),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '৳ ${exp.amount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                        if (exp.id != null) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 18),
                                            onPressed: () => _confirmDeleteExpense(exp),
                                            tooltip: 'মুছে ফেলুন',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedDateFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryGreen,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDateFilter = label;
            _customDateRange = null;
          });
        }
      },
    );
  }
}
