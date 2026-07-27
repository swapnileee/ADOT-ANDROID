import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductModel> _allProducts = [];
  List<SaleModel> _allSales = [];
  List<ExpenseModel> _allExpenses = [];

  List<ProductModel> _matchingProducts = [];
  List<SaleModel> _matchingSales = [];
  List<ExpenseModel> _matchingExpenses = [];

  bool _isLoading = true;
  String _query = '';
  int _selectedFilter = 0; // 0: All, 1: Products, 2: Sales, 3: Expenses

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _supabaseService.fetchProducts();
      final sales = await _supabaseService.fetchSales();
      final expenses = await _supabaseService.fetchExpenses();

      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _allSales = sales;
        _allExpenses = expenses;
        _isLoading = false;
        _performSearch();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  void _performSearch() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      _matchingProducts = List.from(_allProducts);
      _matchingSales = List.from(_allSales);
      _matchingExpenses = List.from(_allExpenses);
    } else {
      _matchingProducts = _allProducts.where((p) {
        return p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
      }).toList();

      _matchingSales = _allSales.where((s) {
        return s.productName.toLowerCase().contains(q) || s.customerName.toLowerCase().contains(q);
      }).toList();

      _matchingExpenses = _allExpenses.where((e) {
        return e.title.toLowerCase().contains(q) || (e.note != null && e.note!.toLowerCase().contains(q));
      }).toList();
    }
  }

  int get _totalResultsCount => _matchingProducts.length + _matchingSales.length + _matchingExpenses.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('সর্বজনীন অনুসন্ধান (Universal Search)'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: AppTheme.primaryGreen,
                  size: 40.0,
                ),
              )
            : Column(
                children: [
                  // Search Input Field
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _query = val;
                          _performSearch();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'পণ্য, ক্রেতার নাম বা খরচের বিবরণ দিয়ে অনুসন্ধান করুন...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _performSearch();
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Filter Choice Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip(0, 'সব ফলাফল ($_totalResultsCount)'),
                        const SizedBox(width: 8),
                        _buildFilterChip(1, 'পণ্য (${_matchingProducts.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip(2, 'বিক্রি (${_matchingSales.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip(3, 'খরচ (${_matchingExpenses.length})'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Results List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        if (_selectedFilter == 0 || _selectedFilter == 1) ...[
                          if (_matchingProducts.isNotEmpty) _buildSectionHeader('পণ্য (${_matchingProducts.length}টি)'),
                          ..._matchingProducts.map((p) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE6F4EA),
                                    child: Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen),
                                  ),
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ক্যাটাগরি: ${p.category} | স্টক: ${p.formattedStock}'),
                                  trailing: Text(
                                    '৳ ${p.baseUnitPrice.toStringAsFixed(2)}/${p.baseUnit}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                  ),
                                ),
                              )),
                        ],

                        if (_selectedFilter == 0 || _selectedFilter == 2) ...[
                          if (_matchingSales.isNotEmpty) _buildSectionHeader('বিক্রি ও অর্ডার (${_matchingSales.length}টি)'),
                          ..._matchingSales.map((s) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFEF7E0),
                                    child: Icon(Icons.shopping_bag_outlined, color: AppTheme.warningOrange),
                                  ),
                                  title: Text(s.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ক্রেতা: ${s.customerName} | পরিমাণ: ${s.displayQuantityWithUnit}'),
                                  trailing: Text(
                                    '৳ ${s.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                  ),
                                ),
                              )),
                        ],

                        if (_selectedFilter == 0 || _selectedFilter == 3) ...[
                          if (_matchingExpenses.isNotEmpty) _buildSectionHeader('দৈনন্দিন খরচ (${_matchingExpenses.length}টি)'),
                          ..._matchingExpenses.map((e) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFCE8E6),
                                    child: Icon(Icons.money_off_rounded, color: AppTheme.errorRed),
                                  ),
                                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(e.note != null && e.note!.isNotEmpty ? 'নোট: ${e.note}' : 'দৈনন্দিন বায়'),
                                  trailing: Text(
                                    '৳ ${e.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                                  ),
                                ),
                              )),
                        ],

                        if (_totalResultsCount == 0)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                'কোন অনুসন্ধানের ফলাফল পাওয়া যায়নি',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = index);
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}
