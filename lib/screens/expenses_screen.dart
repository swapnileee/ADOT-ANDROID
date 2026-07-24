import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../models/expense_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final expenses = await _supabaseService.fetchExpenses();
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'খরচের তালিকা লোড করতে ব্যর্থ: $e');
    }
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final expense = ExpenseModel(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
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
      Navigator.pop(context); // Close modal
      _loadExpenses();
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'খরচ যোগ করতে ত্রুটি হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
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
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'খরচের বিবরণ/শিরোনাম *',
                    hintText: 'যেমন: দোকান ভাড়া, বিদ্যুৎ বিল, নাস্তা',
                    prefixIcon: Icon(Icons.description_outlined,
                        color: AppTheme.primaryGreen),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'বিবরণ প্রদান করুন'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'টাকার পরিমাণ (৳) *',
                    hintText: 'যেমন: ৫০০',
                    prefixIcon: Icon(Icons.attach_money_rounded,
                        color: AppTheme.primaryGreen),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'টাকার পরিমাণ প্রদান করুন';
                    }
                    if (double.tryParse(val.trim()) == null) {
                      return 'সঠিক সংখ্যা প্রদান করুন';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'অতিরিক্ত নোট (ঐচ্ছিক)',
                    hintText: 'কোন বিশেষ মন্তব্য থাকলে লিখুন',
                    prefixIcon: Icon(Icons.note_alt_outlined,
                        color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _addExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                    child: _isSubmitting
                        ? const SpinKitThreeBounce(
                            color: Colors.white, size: 20)
                        : const Text('খরচ সংরক্ষণ করুন',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double get _totalExpensesSum {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'মেনু খুলুন',
        ),
        title: const Text('দৈনন্দিন খরচ (Expenses)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseModal,
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('নতুন খরচ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              onRefresh: _loadExpenses,
              child: Column(
                children: [
                  // Total Expenses Summary Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.errorRed.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'মোট খরচ তালিকা',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'সাম্প্রতিক বায় সমুহ',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        Text(
                          '৳ ${_totalExpensesSum.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expenses List
                  Expanded(
                    child: _expenses.isEmpty
                        ? const Center(
                            child: Text(
                              'কোন খরচের তথ্য পাওয়া যায়নি',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final exp = _expenses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.errorRed
                                        .withValues(alpha: 0.12),
                                    child: const Icon(Icons.money_off_rounded,
                                        color: AppTheme.errorRed),
                                  ),
                                  title: Text(
                                    exp.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (exp.note != null &&
                                          exp.note!.isNotEmpty)
                                        Text('নোট: ${exp.note}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      if (exp.createdAt != null)
                                        Text(
                                          dateFormat.format(exp.createdAt!),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                  trailing: Text(
                                    '৳ ${exp.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.errorRed,
                                    ),
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
}
