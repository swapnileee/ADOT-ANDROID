import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../models/staff_model.dart';
import '../models/salary_payment_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_snackbar.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<StaffModel> _staffList = [];
  List<SalaryPaymentModel> _salaryPayments = [];
  bool _isLoading = true;
  String _selectedFilter = 'সকল'; // 'সকল', 'সক্রিয়', 'নিষ্ক্রিয়'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _supabaseService.fetchStaff();
      final payments = await _supabaseService.fetchSalaryPayments();

      if (!mounted) return;
      setState(() {
        _staffList = staff;
        _salaryPayments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'ডাটা লোড করতে সমস্যা হয়েছে: $e');
    }
  }

  List<StaffModel> get _filteredStaff {
    if (_selectedFilter == 'সক্রিয়') {
      return _staffList.where((s) => s.isActive).toList();
    } else if (_selectedFilter == 'নিষ্ক্রিয়') {
      return _staffList.where((s) => !s.isActive).toList();
    }
    return _staffList;
  }

  double get _totalMonthlyPayroll {
    return _staffList
        .where((s) => s.isActive)
        .fold(0.0, (sum, s) => sum + s.monthlySalary);
  }

  int get _unpaidCurrentMonthCount {
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    final paidStaffIds = _salaryPayments
        .where((p) => p.monthYear.trim().toLowerCase() == currentMonthYear.trim().toLowerCase())
        .map((p) => p.staffId)
        .toSet();

    return _staffList.where((s) => s.isActive && !paidStaffIds.contains(s.id.toString())).length;
  }

  bool _isSalaryPaidForMonth(String staffId, String monthYear) {
    return _salaryPayments.any((p) =>
        p.staffId.toString() == staffId.toString() &&
        p.monthYear.trim().toLowerCase() == monthYear.trim().toLowerCase());
  }

  void _showAddOrEditStaffModal({StaffModel? staffToEdit}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: staffToEdit?.name ?? '');
    final designationController = TextEditingController(text: staffToEdit?.designation ?? 'Salesman');
    final phoneController = TextEditingController(text: staffToEdit?.phone ?? '');
    final salaryController = TextEditingController(
        text: staffToEdit != null ? staffToEdit.monthlySalary.toStringAsFixed(0) : '');

    DateTime selectedJoinDate = staffToEdit?.joinDate ?? DateTime.now();
    String status = staffToEdit?.status ?? 'active';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            staffToEdit == null ? 'নতুন স্টাফ যোগ করুন' : 'স্টাফ তথ্য সম্পাদনা',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'স্টাফের নাম *',
                          hintText: 'যেমন: করিম হোসেন',
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'নাম লিখুন' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: designationController,
                        decoration: InputDecoration(
                          labelText: 'পদবী / দায়িত্ব *',
                          hintText: 'যেমন: সেলসম্যান, ম্যানেজার',
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'পদবী লিখুন' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'মোবাইল নম্বর *',
                          hintText: 'যেমন: 01711XXXXXX',
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'মোবাইল নম্বর লিখুন' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: salaryController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'মাসিক বেতন (৳) *',
                          hintText: 'যেমন: 15000',
                          prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'মাসিক বেতন লিখুন';
                          if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা লিখুন';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // JOIN DATE PICKER
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedJoinDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedJoinDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryGreen),
                              const SizedBox(width: 10),
                              Text(
                                'যোগদানের তারিখ: ${DateFormat('dd MMMM yyyy').format(selectedJoinDate)}',
                                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (staffToEdit != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('স্ট্যাটাস: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            ChoiceChip(
                              label: const Text('সক্রিয়'),
                              selected: status == 'active',
                              selectedColor: AppTheme.primaryGreen,
                              labelStyle: TextStyle(color: status == 'active' ? Colors.white : AppTheme.textDark),
                              onSelected: (val) {
                                if (val) setModalState(() => status = 'active');
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('নিষ্ক্রিয়'),
                              selected: status == 'inactive',
                              selectedColor: AppTheme.errorRed,
                              labelStyle: TextStyle(color: status == 'inactive' ? Colors.white : AppTheme.textDark),
                              onSelected: (val) {
                                if (val) setModalState(() => status = 'inactive');
                              },
                            ),
                          ],
                        ),
                      ],

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

                                  final nav = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final isEdit = staffToEdit != null;

                                  try {
                                    final salary = double.parse(salaryController.text.trim());
                                    if (staffToEdit == null) {
                                      final newStaff = StaffModel(
                                        name: nameController.text.trim(),
                                        designation: designationController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        joinDate: selectedJoinDate,
                                        monthlySalary: salary,
                                        pendingSalary: salary,
                                        status: 'active',
                                        createdAt: DateTime.now(),
                                      );
                                      await _supabaseService.addStaff(newStaff);
                                    } else {
                                      final updated = staffToEdit.copyWith(
                                        name: nameController.text.trim(),
                                        designation: designationController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        joinDate: selectedJoinDate,
                                        monthlySalary: salary,
                                        status: status,
                                      );
                                      await _supabaseService.updateStaff(updated);
                                    }

                                    if (!mounted) return;
                                    nav.pop();
                                    await _loadData();
                                    if (!mounted) return;

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                isEdit
                                                    ? 'স্টাফ তথ্য আপডেট হয়েছে!'
                                                    : 'নতুন স্টাফ সফলভাবে সংরক্ষণ হয়েছে!',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
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
                                     messenger.showSnackBar(
                                       SnackBar(
                                         content: Row(
                                           children: [
                                             const Icon(Icons.error_outline_rounded, color: Colors.white),
                                             const SizedBox(width: 12),
                                             Expanded(
                                               child: Text(
                                                 'সংরক্ষণ করতে সমস্যা হয়েছে: $e',
                                                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                               ),
                                             ),
                                           ],
                                         ),
                                         backgroundColor: const Color(0xFFD32F2F),
                                         behavior: SnackBarBehavior.floating,
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                         margin: const EdgeInsets.all(16),
                                         duration: const Duration(seconds: 4),
                                       ),
                                     );
                                   } finally {
                                    setModalState(() => isSubmitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                              : Text(
                                  staffToEdit == null ? 'স্টাফ যুক্ত করুন' : 'আপডেট করুন',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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

  void _showPaySalaryModal(StaffModel staff) {
    final formKey = GlobalKey<FormState>();
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    final prevMonthYear = DateFormat('MMMM yyyy').format(DateTime.now().subtract(const Duration(days: 30)));
    final nextMonthYear = DateFormat('MMMM yyyy').format(DateTime.now().add(const Duration(days: 30)));

    final List<String> monthOptions = [prevMonthYear, currentMonthYear, nextMonthYear];
    String selectedMonthYear = currentMonthYear;

    final amountController = TextEditingController(text: staff.monthlySalary.toStringAsFixed(0));
    final notesController = TextEditingController();
    bool addAsExpense = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAlreadyPaid = _isSalaryPaidForMonth(staff.id.toString(), selectedMonthYear);

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
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                '${staff.name}-কে বেতন প্রদান',
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
                      const SizedBox(height: 12),

                      if (isAlreadyPaid)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.warningOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$selectedMonthYear মাসের বেতন ইতোমধ্যে প্রদান করা হয়েছে!',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Month Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedMonthYear,
                        decoration: InputDecoration(
                          labelText: 'বেতনের মাস ও বছর *',
                          prefixIcon: const Icon(Icons.calendar_month, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: monthOptions.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedMonthYear = val);
                          }
                        },
                      ),

                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'প্রদত্ত টাকার পরিমাণ (৳) *',
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
                      TextFormField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'নোট / বিবরণ (ঐচ্ছিক)',
                          hintText: 'যেমন: অগ্রিম / বোনাস',
                          prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: addAsExpense,
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'দোকানের খরচে (Expense Tracker) অন্তর্ভুক্ত করুন',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onChanged: (val) => setModalState(() => addAsExpense = val ?? true),
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setModalState(() => isSubmitting = true);

                                      final nav = Navigator.of(context);
                                      final messenger = ScaffoldMessenger.of(context);

                                      try {
                                        final amount = double.parse(amountController.text.trim());
                                        final payment = SalaryPaymentModel(
                                          staffId: staff.id.toString(),
                                          staffName: staff.name,
                                          amountPaid: amount,
                                          paymentDate: DateTime.now(),
                                          monthYear: selectedMonthYear,
                                          notes: notesController.text.trim().isNotEmpty
                                              ? notesController.text.trim()
                                              : null,
                                          createdAt: DateTime.now(),
                                        );

                                        await _supabaseService.processSalaryPayment(
                                          payment: payment,
                                          addAsExpense: addAsExpense,
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
                                                    '$selectedMonthYear মাসের বেতন প্রদান সম্পন্ন হয়েছে!',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
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
                                        _loadData();
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.error_outline_rounded, color: Colors.white),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'বেতন প্রদান করতে সমস্যা হয়েছে: $e',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFFD32F2F),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            margin: const EdgeInsets.all(16),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      } finally {
                                        setModalState(() => isSubmitting = false);
                                      }
                                    },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                              : const Text(
                                  'বেতন নিশ্চিত করুন',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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

  void _showSalaryHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'বেতন প্রদানের ইতিহাস',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _salaryPayments.isEmpty
                    ? const Center(
                        child: Text('কোন বেতনের রেকর্ড পাওয়া যায়নি', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _salaryPayments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _salaryPayments[index];
                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.paymentDate);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              child: const Icon(Icons.badge_rounded, color: AppTheme.primaryGreen),
                            ),
                            title: Text(item.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('মাস: ${item.monthYear} | তারিখ: $dateStr'),
                            trailing: Text(
                              '৳ ${item.amountPaid.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryGreen),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'কর্মচারী ব্যবস্থাপনা',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'বেতন ইতিহাস',
            onPressed: _showSalaryHistoryModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: SpinKitFadingCube(color: AppTheme.primaryGreen, size: 40.0))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SUMMARY METRICS CARDS
                  _buildSummaryHeader(),

                  const SizedBox(height: 16),

                  // 2. ACTION ROW & FILTER CHIPS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: ['সকল', 'সক্রিয়', 'নিষ্ক্রিয়'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryGreen,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.white,
                              onSelected: (_) {
                                setState(() => _selectedFilter = filter);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrEditStaffModal(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: const Text(
                          'নতুন স্টাফ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. STAFF LIST
                  _filteredStaff.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.badge_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'কোন কর্মচারী পাওয়া যায়নি',
                                  style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredStaff.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final staff = _filteredStaff[index];
                            return _buildStaffCard(staff);
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryHeader() {
    final activeCount = _staffList.where((s) => s.isActive).length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'সক্রিয় কর্মী',
            '$activeCount জন',
            Icons.people_outline_rounded,
            const Color(0xFF1565C0),
            const Color(0xFFE3F2FD),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            'মাসিক মোট বেতন',
            '৳ ${_totalMonthlyPayroll.toStringAsFixed(0)}',
            Icons.payments_outlined,
            const Color(0xFF2E7D32),
            const Color(0xFFE8F5E9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            'চলতি মাসের বাকি',
            '$_unpaidCurrentMonthCount জন',
            Icons.warning_amber_rounded,
            AppTheme.warningOrange,
            const Color(0xFFFFF3E0),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffModel staff) {
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    final isPaidThisMonth = _isSalaryPaidForMonth(staff.id.toString(), currentMonthYear);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  child: Text(
                    staff.name.isNotEmpty ? staff.name.substring(0, 1) : 'S',
                    style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            staff.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: staff.isActive
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.isActive ? 'সক্রিয়' : 'নিষ্ক্রিয়',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: staff.isActive ? AppTheme.primaryGreen : AppTheme.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${staff.designation} • 📱 ${staff.phone}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('মাসিক বেতন', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '৳ ${staff.monthlySalary.toStringAsFixed(0)} / মাস',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaidThisMonth ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isPaidThisMonth ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaidThisMonth ? Icons.check_circle_outline : Icons.error_outline_rounded,
                        size: 14,
                        color: isPaidThisMonth ? Colors.green.shade700 : AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaidThisMonth ? '$currentMonthYear: পরিশোধিত' : '$currentMonthYear: বেতন বাকি',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPaidThisMonth ? Colors.green.shade700 : AppTheme.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'যোগদান: ${DateFormat('dd MMM yyyy').format(staff.joinDate)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddOrEditStaffModal(staffToEdit: staff),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.black54),
                      label: const Text('এডিট', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showPaySalaryModal(staff),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 14, color: Colors.white),
                      label: const Text('বেতন দিন',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
