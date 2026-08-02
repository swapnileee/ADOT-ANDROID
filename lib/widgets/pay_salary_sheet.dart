import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/staff_model.dart';
import '../models/salary_payment_model.dart';
import '../theme/app_theme.dart';

class PaySalarySheet extends StatefulWidget {
  final StaffModel staff;
  final List<SalaryPaymentModel> salaryPayments;
  final Future<void> Function({
    required SalaryPaymentModel payment,
    required bool addAsExpense,
  }) onPaymentSubmit;

  const PaySalarySheet({
    super.key,
    required this.staff,
    required this.salaryPayments,
    required this.onPaymentSubmit,
  });

  @override
  State<PaySalarySheet> createState() => _PaySalarySheetState();
}

class _PaySalarySheetState extends State<PaySalarySheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();

  late List<String> _allMonths;
  late List<String> _unpaidMonths;
  late String _selectedSingleMonth;

  int _paymentMode = 0; // 0: Single Month ("নির্দিষ্ট ১ মাস"), 1: All Dues ("সকল বকেয়া একসাথে")
  bool _addAsExpense = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _allMonths = _generateAllMonths(widget.staff.joinDate, DateTime.now());
    _unpaidMonths = _calculateUnpaidMonths(widget.staff.joinDate, DateTime.now());

    if (_unpaidMonths.isNotEmpty) {
      _selectedSingleMonth = _unpaidMonths.first;
    } else if (_allMonths.isNotEmpty) {
      _selectedSingleMonth = _allMonths.first;
    } else {
      _selectedSingleMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    }

    _amountController = TextEditingController(
      text: widget.staff.monthlySalary.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _isSalaryPaidForMonth(String monthYear) {
    return widget.salaryPayments.any((p) =>
        p.staffId.toString() == widget.staff.id.toString() &&
        p.monthYear.trim().toLowerCase() == monthYear.trim().toLowerCase());
  }

  List<String> _generateAllMonths(DateTime joinDate, DateTime now) {
    DateTime current = DateTime(joinDate.year, joinDate.month, 1);
    final DateTime limit = DateTime(now.year, now.month, 1);

    if (current.isAfter(limit)) {
      return [DateFormat('MMMM yyyy').format(limit)];
    }

    final List<String> months = [];
    while (!current.isAfter(limit)) {
      months.add(DateFormat('MMMM yyyy').format(current));
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months.reversed.toList();
  }

  List<String> _calculateUnpaidMonths(DateTime joinDate, DateTime now) {
    if (joinDate.year > now.year ||
        (joinDate.year == now.year && joinDate.month >= now.month)) {
      return [];
    }

    final List<String> unpaid = [];
    DateTime current = DateTime(joinDate.year, joinDate.month, 1);
    final DateTime limit = DateTime(now.year, now.month, 1);

    while (!current.isAfter(limit)) {
      final monthStr = DateFormat('MMMM yyyy').format(current);
      if (!_isSalaryPaidForMonth(monthStr)) {
        unpaid.add(monthStr);
      }
      current = DateTime(current.year, current.month + 1, 1);
    }
    return unpaid;
  }

  void _switchPaymentMode(int mode) {
    setState(() {
      _paymentMode = mode;
      if (mode == 0) {
        // Single Month Mode
        _amountController.text = widget.staff.monthlySalary.toStringAsFixed(0);
        _notesController.text = '';
      } else {
        // All Dues Mode
        final count = _unpaidMonths.isNotEmpty ? _unpaidMonths.length : 1;
        final totalDue = count * widget.staff.monthlySalary;
        _amountController.text = totalDue.toStringAsFixed(0);
        _notesController.text = 'সকল বকেয়া একত্রে: $count মাস';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalUnpaidCount = _unpaidMonths.isNotEmpty ? _unpaidMonths.length : 1;
    final totalUnpaidAmount = totalUnpaidCount * widget.staff.monthlySalary;
    final isSingleMonthPaid = _isSalaryPaidForMonth(_selectedSingleMonth);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.staff.name}-কে বেতন প্রদান',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. PAYMENT MODE SELECTOR (Segmented Choice Chips)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('নির্দিষ্ট ১ মাসের বেতন')),
                        selected: _paymentMode == 0,
                        selectedColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _paymentMode == 0 ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          if (selected) _switchPaymentMode(0);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            _unpaidMonths.length > 1
                                ? 'সকল বকেয়া (${_unpaidMonths.length} মাস)'
                                : 'সকল বকেয়া একসাথে',
                          ),
                        ),
                        selected: _paymentMode == 1,
                        selectedColor: AppTheme.warningOrange,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _paymentMode == 1 ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          _switchPaymentMode(selected ? 1 : 0);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. DYNAMIC CONTENT BASED ON SELECTED MODE
                if (_paymentMode == 0) ...[
                  // Single Month Dropdown Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSingleMonth,
                    decoration: InputDecoration(
                      labelText: 'বেতনের মাস নির্বাচন করুন *',
                      prefixIcon: const Icon(Icons.calendar_month, color: AppTheme.primaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _allMonths.map((m) {
                      final paid = _isSalaryPaidForMonth(m);
                      return DropdownMenuItem(
                        value: m,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(m),
                            const SizedBox(width: 12),
                            Text(
                              paid ? '(পরিশোধিত)' : '(বাকি)',
                              style: TextStyle(
                                fontSize: 12,
                                color: paid ? Colors.green.shade700 : AppTheme.warningOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSingleMonth = val;
                          _amountController.text = widget.staff.monthlySalary.toStringAsFixed(0);
                        });
                      }
                    },
                  ),

                  if (isSingleMonthPaid) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.warningOrange, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$_selectedSingleMonth মাসের বেতন ইতোমধ্যে প্রদান করা হয়েছে',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.warningOrange, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // All Dues Mode Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.warningOrange, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalUnpaidCount মাস বকেয়া • মোট ৳${totalUnpaidAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                              if (_unpaidMonths.isNotEmpty)
                                Text(
                                  'বকেয়া মাসসমূহ: ${_unpaidMonths.join(", ")}',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Amount Field (Auto-Synced)
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'প্রদত্ত টাকার পরিমাণ (৳) *',
                    helperText: _paymentMode == 1
                        ? '$totalUnpaidCount মাসের মোট বকেয়া বেতন'
                        : '১ মাসের মূল বেতন',
                    prefixText: '৳ ',
                    prefixIcon: const Icon(Icons.money_rounded, color: AppTheme.primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'টাকার পরিমাণ লিখুন';
                    if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা লিখুন';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'নোট / বিবরণ (ঐচ্ছিক)',
                    hintText: 'যেমন: অগ্রিম / বোনাস',
                    prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // Include in Expense Tracker Checkbox
                CheckboxListTile(
                  value: _addAsExpense,
                  activeColor: AppTheme.primaryGreen,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'দোকানের খরচে (Expense Tracker) অন্তর্ভুক্ত করুন',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) => setState(() => _addAsExpense = val ?? true),
                ),

                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _isSubmitting = true);

                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            try {
                              final amount = double.parse(_amountController.text.trim());
                              final monthYearLabel = _paymentMode == 1
                                  ? (_unpaidMonths.isNotEmpty
                                      ? _unpaidMonths.join(", ")
                                      : _selectedSingleMonth)
                                  : _selectedSingleMonth;

                              final payment = SalaryPaymentModel(
                                staffId: widget.staff.id.toString(),
                                staffName: widget.staff.name,
                                amountPaid: amount,
                                paymentDate: DateTime.now(),
                                monthYear: monthYearLabel,
                                notes: _notesController.text.trim().isNotEmpty
                                    ? _notesController.text.trim()
                                    : null,
                                createdAt: DateTime.now(),
                              );

                              await widget.onPaymentSubmit(
                                payment: payment,
                                addAsExpense: _addAsExpense,
                              );

                              if (!mounted) return;
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '$monthYearLabel মাসের বেতন প্রদান সম্পন্ন হয়েছে!',
                                          style: const TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF1E4D3B),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('বেতন প্রদান ব্যর্থ: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                        : const Text(
                            'বেতন প্রদান সম্পন্ন করুন',
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
  }
}
