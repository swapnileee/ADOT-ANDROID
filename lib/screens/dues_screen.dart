import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/shop_info_service.dart';
import '../services/supabase_service.dart';
import '../models/sale_model.dart';
import '../models/due_collection_model.dart';
import '../widgets/custom_snackbar.dart';

enum DueFilterMode { all, todayCollectible, collectedThisMonth }

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  static const Color primaryDarkGreen = Color(0xFF1E4D3B);
  static const Color bgLightGray = Color(0xFFF8F9FA);
  static const Color cardBorderColor = Color(0xFFE5E7EB);
  static const Color textDark = Color(0xFF1F2937);

  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  double _totalDue = 0.0;
  double _todayDue = 0.0;
  double _collectedThisMonth = 0.0;
  int _todayDueCount = 0;

  DueFilterMode _filterMode = DueFilterMode.all;
  List<SaleModel> _allDueSales = [];
  List<DueCollectionModel> _monthDueCollectionsList = [];

  String _searchQuery = '';
  String _selectedSort = 'সর্বশেষ যোগ'; // 'বেশি বকেয়া আগে', 'পুরনো বকেয়া আগে', 'নাম (A-Z)', 'সর্বশেষ যোগ'

  @override
  void initState() {
    super.initState();
    _loadDuesData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDuesData() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      double dueSum = 0.0;
      double todayDueSum = 0.0;
      double monthCollectedSum = 0.0;
      int todayCount = 0;

      final now = DateTime.now();
      final List<SaleModel> dues = [];

      for (var s in sales) {
        if (s.dueAmount > 0) {
          dues.add(s);
          dueSum += s.dueAmount;

          // Calculate dues older than or equal to 7 days (Age >= 7 days)
          final dt = s.createdAt?.toLocal() ?? now;
          final daysOld = now.difference(dt).inDays;
          if (daysOld >= 7) {
            todayDueSum += s.dueAmount;
            todayCount++;
          }
        }
      }

      // Collected this month strictly from Due Collections / Repayments
      final dueCollections = await _supabaseService.fetchDueCollections();
      final List<DueCollectionModel> monthCollections = [];
      for (var c in dueCollections) {
        final dt = c.createdAt.toLocal();
        if (dt.year == now.year && dt.month == now.month) {
          monthCollectedSum += c.amount;
          monthCollections.add(c);
        }
      }

      if (!mounted) return;
      setState(() {
        _allDueSales = dues;
        _monthDueCollectionsList = monthCollections;
        _totalDue = dueSum;
        _todayDue = todayDueSum;
        _todayDueCount = todayCount;
        _collectedThisMonth = monthCollectedSum;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'বকেয়া ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  List<SaleModel> get _filteredAndSortedList {
    List<SaleModel> rawList = [];
    final now = DateTime.now();

    if (_filterMode == DueFilterMode.todayCollectible) {
      rawList = _allDueSales.where((s) {
        final dt = s.createdAt?.toLocal() ?? now;
        return now.difference(dt).inDays >= 7;
      }).toList();
    } else if (_filterMode == DueFilterMode.collectedThisMonth) {
      rawList = _monthDueCollectionsList.map((c) {
        return SaleModel(
          id: c.id,
          customerName: c.customerName,
          customerPhone: '',
          productName: 'বকেয়া পাওনা আদায়',
          quantity: 1,
          totalPrice: c.amount,
          paidAmount: c.amount,
          dueAmount: 0.0,
          createdAt: c.createdAt,
        );
      }).toList();
    } else {
      rawList = List.from(_allDueSales);
    }

    List<SaleModel> list = rawList.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = s.customerName.toLowerCase();
      final phone = (s.customerPhone ?? '').toLowerCase();
      final product = s.productName.toLowerCase();
      return name.contains(q) || phone.contains(q) || product.contains(q);
    }).toList();

    if (_selectedSort == 'বেশি বকেয়া আগে') {
      list.sort((a, b) {
        final double valA = a.dueAmount > 0 ? a.dueAmount : a.paidAmount;
        final double valB = b.dueAmount > 0 ? b.dueAmount : b.paidAmount;
        return valB.compareTo(valA);
      });
    } else if (_selectedSort == 'পুরনো বকেয়া আগে') {
      list.sort((a, b) => (a.createdAt ?? now).compareTo(b.createdAt ?? now));
    } else if (_selectedSort == 'নাম (A-Z)') {
      list.sort((a, b) => a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()));
    } else {
      // 'সর্বশেষ যোগ'
      list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    }

    return list;
  }

  String get _headerTitle {
    final count = _filteredAndSortedList.length;
    switch (_filterMode) {
      case DueFilterMode.todayCollectible:
        return 'আজ আদায়যোগ্য বকেয়া ($count)';
      case DueFilterMode.collectedThisMonth:
        return 'চলতি মাসের আদায় তালিকা ($count)';
      case DueFilterMode.all:
        return 'বকেয়া তালিকা ($count)';
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      CustomSnackBar.showError(context, 'মোবাইল নম্বর দেওয়া নেই!');
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) CustomSnackBar.showError(context, 'কল করা সম্ভব হয়নি');
    }
  }

  Future<void> _sendDirectSms(SaleModel sale) async {
    final String phone = sale.customerPhone?.trim() ?? '';
    if (phone.isEmpty) {
      if (mounted) CustomSnackBar.showError(context, 'গ্রাহকের মোবাইল নম্বর পাওয়া যায়নি!');
      return;
    }

    final String name = sale.customerName.isEmpty ? 'সম্মানিত গ্রাহক' : sale.customerName;
    final String due = sale.dueAmount.toStringAsFixed(0);
    final String shopName = ShopInfoService.shopInfoNotifier.value.name;

    final String message =
        'প্রিয় $name, $shopName-এ আপনার বকেয়া পাওনা ৳ $due টাকা। অনুগ্রহ করে বকেয়া পরিশোধ করার জন্য অনুরোধ করা হচ্ছে। ধন্যবাদ!';
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{'body': message},
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'মেসেজ অ্যাপ খুলতে সমস্যা হয়েছে: $e');
    }
  }

  void _showCollectOrEditDueDialog(SaleModel sale) {
    int selectedMode = 0; // 0 = Collect Payment, 1 = Add New Credit
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            final double inputVal = double.tryParse(amountController.text.trim()) ?? 0.0;
            final double previewPaid = selectedMode == 0 ? (sale.paidAmount + inputVal) : sale.paidAmount;
            final double previewDue = selectedMode == 0
                ? (sale.dueAmount - inputVal > 0 ? sale.dueAmount - inputVal : 0.0)
                : (sale.dueAmount + inputVal);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'বকেয়া এন্ট্রি - ${sale.customerName.isEmpty ? "নগদ কাস্টমার" : sale.customerName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  Text(
                    'পণ্য: ${sale.productName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('১. পেমেন্ট গ্রহণ'),
                              selected: selectedMode == 0,
                              selectedColor: primaryDarkGreen,
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: selectedMode == 0 ? Colors.white : textDark,
                                fontWeight: selectedMode == 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedMode = 0);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('২. নতুন বাকি যোগ'),
                              selected: selectedMode == 1,
                              selectedColor: const Color(0xFFEF6C00),
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: selectedMode == 1 ? Colors.white : textDark,
                                fontWeight: selectedMode == 1 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedMode = 1);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedMode == 0 ? 'সংগৃহীত টাকার পরিমাণ (৳) *' : 'অতিরিক্ত বাকির পরিমাণ (৳) *',
                          prefixIcon: Icon(
                            selectedMode == 0 ? Icons.payments_outlined : Icons.add_circle_outline_rounded,
                            color: selectedMode == 0 ? primaryDarkGreen : const Color(0xFFEF6C00),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setModalState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'টাকার পরিমাণ লিখুন';
                          if (double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                            return 'সঠিক সংখ্যা প্রদান করুন';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryDarkGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryDarkGreen.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('পূর্বের বকেয়া:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('৳ ${sale.dueAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedMode == 0 ? 'নতুন পরিশোধিত:' : 'নতুন বাকিসহ বকেয়া:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text(
                                  selectedMode == 0
                                      ? '৳ ${previewPaid.toStringAsFixed(0)}'
                                      : '৳ ${previewDue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('সমন্বয় পরবর্তী বকেয়া:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(
                                  previewDue <= 0 ? 'পরিশোধিত (৳ 0)' : '৳ ${previewDue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: previewDue <= 0 ? primaryDarkGreen : const Color(0xFFD32F2F),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('বাতিল'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);
                          try {
                            await _supabaseService.updateSaleDue(
                              saleId: sale.id,
                              newPaidAmount: previewPaid,
                              newDueAmount: previewDue,
                            );

                            if (selectedMode == 0 && inputVal > 0) {
                              await _supabaseService.recordDueCollection(
                                customerName: sale.customerName.isEmpty ? 'নগদ কাস্টমার' : sale.customerName,
                                amount: inputVal,
                                saleId: sale.id.toString(),
                              );
                            }
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              CustomSnackBar.showSuccess(context, 'বকেয়া হিসাব সফলভাবে আপডেট হয়েছে!');
                              _loadDuesData();
                            }
                          } catch (e) {
                            if (mounted) CustomSnackBar.showError(context, 'বকেয়া আপডেট করতে সমস্যা: $e');
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDarkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                      : const Text('সংরক্ষণ করুন', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddNewDueModal() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final productController = TextEditingController();
    final totalAmountController = TextEditingController();
    final paidAmountController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final double total = double.tryParse(totalAmountController.text.trim()) ?? 0.0;
            final double paid = double.tryParse(paidAmountController.text.trim()) ?? 0.0;
            final double computedDue = total - paid > 0 ? total - paid : 0.0;

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                          const Text(
                            '+ নতুন বকেয়া যোগ করুন',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'গ্রাহকের নাম *',
                          prefixIcon: const Icon(Icons.person_outline, color: primaryDarkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'গ্রাহকের নাম আবশ্যক' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'মোবাইল নম্বর',
                          prefixIcon: const Icon(Icons.phone_outlined, color: primaryDarkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: productController,
                        decoration: InputDecoration(
                          labelText: 'পণ্যের নাম / বিবরণ *',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined, color: primaryDarkGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'পণ্যের নাম আবশ্যক' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: totalAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'মোট মূল্য (৳) *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (_) => setModalState(() {}),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'দাম লিখুন';
                                if (double.tryParse(val.trim()) == null) return 'সঠিক সংখ্যা';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: paidAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'জমা টাকা (৳)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('অবশিষ্ট বকেয়া:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                            Text(
                              '৳ ${computedDue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
                            ),
                          ],
                        ),
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
                                  try {
                                    final double tot = double.parse(totalAmountController.text.trim());
                                    final double pd = double.tryParse(paidAmountController.text.trim()) ?? 0.0;
                                    final double due = tot - pd > 0 ? tot - pd : 0.0;

                                    await _supabaseService.recordSale(SaleModel(
                                      id: '',
                                      customerName: nameController.text.trim(),
                                      customerPhone: phoneController.text.trim(),
                                      productName: productController.text.trim(),
                                      quantity: 1,
                                      totalPrice: tot,
                                      paidAmount: pd,
                                      dueAmount: due,
                                      createdAt: DateTime.now().toUtc(),
                                    ));

                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                    if (mounted) {
                                      CustomSnackBar.showSuccess(context, 'নতুন বকেয়া সফলভাবে যুক্ত হয়েছে!');
                                      _loadDuesData();
                                    }
                                  } catch (e) {
                                    if (mounted) CustomSnackBar.showError(context, 'বকেয়া যুক্ত করতে সমস্যা: $e');
                                  } finally {
                                    setModalState(() => isSubmitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryDarkGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                              : const Text('সংরক্ষণ করুন',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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

  void _showSortFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'বকেয়া ফিল্টার ও সর্টিং',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDarkGreen),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'সর্বশেষ যোগ',
                    'বেশি বকেয়া আগে',
                    'পুরনো বকেয়া আগে',
                    'নাম (A-Z)',
                  ].map((sortOption) {
                    final isSel = _selectedSort == sortOption;
                    return ListTile(
                      title: Text(
                        sortOption,
                        style: TextStyle(
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? primaryDarkGreen : textDark,
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check_circle_rounded, color: primaryDarkGreen) : null,
                      onTap: () {
                        setState(() {
                          _selectedSort = sortOption;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredAndSortedList;

    return Scaffold(
      backgroundColor: bgLightGray,
      appBar: AppBar(
        backgroundColor: primaryDarkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'বকেয়া খাতা',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '(Due Management)',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadDuesData,
            tooltip: 'রিফ্রেশ',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SpinKitFadingCube(
                  color: primaryDarkGreen,
                  size: 40.0,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDuesData,
                color: primaryDarkGreen,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildSmartSummaryRow(),
                    const SizedBox(height: 20),
                    _buildHeaderAndActionRow(),
                    const SizedBox(height: 12),
                    if (displayList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'কোনো রেকর্ড পাওয়া যায়নি',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final sale = displayList[index];
                          return _buildCustomerDueCard(sale);
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'নাম বা মোবাইল দিয়ে খুঁজুন',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20, color: primaryDarkGreen),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _showSortFilterBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: const Icon(Icons.filter_list_rounded, color: primaryDarkGreen, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'মোট বকেয়া',
            value: '৳ ${_totalDue.toStringAsFixed(0)}',
            valueColor: const Color(0xFFD32F2F),
            subtext: '${_allDueSales.length} জন গ্রাহক',
            isSelected: _filterMode == DueFilterMode.all,
            onTap: () {
              setState(() {
                _filterMode = DueFilterMode.all;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'আজ আদায়যোগ্য',
            value: '৳ ${_todayDue.toStringAsFixed(0)}',
            valueColor: const Color(0xFFEF6C00),
            subtext: '$_todayDueCountটি বকেয়া (৭+ দিন)',
            isSelected: _filterMode == DueFilterMode.todayCollectible,
            onTap: () {
              setState(() {
                _filterMode = DueFilterMode.todayCollectible;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'আদায় করা হয়েছে',
            value: '৳ ${_collectedThisMonth.toStringAsFixed(0)}',
            valueColor: const Color(0xFF2E7D32),
            subtext: 'চলতি মাস',
            isSelected: _filterMode == DueFilterMode.collectedThisMonth,
            onTap: () {
              setState(() {
                _filterMode = DueFilterMode.collectedThisMonth;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color valueColor,
    required String subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? valueColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? valueColor : cardBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: valueColor.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? valueColor : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? valueColor : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAndActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _headerTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDarkGreen),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ElevatedButton(
          onPressed: _showAddNewDueModal,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryDarkGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 0,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '+ নতুন বকেয়া',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerDueCard(SaleModel sale) {
    final bool isCollected = sale.dueAmount <= 0;
    final String initial = sale.customerName.isNotEmpty ? sale.customerName[0].toUpperCase() : 'N';
    final String name = sale.customerName.isEmpty ? 'নগদ কাস্টমার' : sale.customerName;
    final String phone = (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
        ? sale.customerPhone!
        : 'মোবাইল নম্বর নেই';
    final String dateStr = sale.createdAt != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(sale.createdAt!.toLocal())
        : 'আজ';

    final Color badgeBg = isCollected ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final Color badgeColor = isCollected ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final String badgeText = isCollected ? 'আদায়কৃত' : 'বকেয়া';
    final String displayAmountText = isCollected
        ? '৳ ${sale.paidAmount.toStringAsFixed(0)}'
        : '৳ ${sale.dueAmount.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Info, Badge & Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: badgeBg,
                child: Text(
                  initial,
                  style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'পণ্য: ${sale.productName}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primaryDarkGreen),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayAmountText,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 20),

          // Bottom Action Row
          Row(
            children: [
              // Button 1: SMS
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () => _sendDirectSms(sale),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_outlined, size: 15, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          'SMS পাঠান',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 2: Collect / Entry
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () => _showCollectOrEditDueDialog(sale),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 15, color: Color(0xFFEF6C00)),
                        SizedBox(width: 4),
                        Text(
                          'আদায় / এন্ট্রি',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF6C00)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Button 3: More Popup Menu
              PopupMenuButton<String>(
                tooltip: '',
                onSelected: (val) {
                  if (val == 'call') {
                    _makePhoneCall(sale.customerPhone ?? '');
                  } else if (val == 'edit') {
                    _showCollectOrEditDueDialog(sale);
                  } else if (val == 'details') {
                    _showDetailsDialog(sale);
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'call',
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 18, color: primaryDarkGreen),
                        SizedBox(width: 8),
                        Text('কল করুন'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFFEF6C00)),
                        SizedBox(width: 8),
                        Text('হিসাব এডিট'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Color(0xFF1565C0)),
                        SizedBox(width: 8),
                        Text('বিস্তারিত দেখুন'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(SaleModel sale) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(sale.customerName.isEmpty ? 'বকেয়া বিবরণ' : sale.customerName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('মোবাইল: ${sale.customerPhone ?? "নেই"}'),
              Text('পণ্য: ${sale.productName}'),
              const SizedBox(height: 8),
              Text('মোট মূল্য: ৳ ${sale.totalPrice.toStringAsFixed(0)}'),
              Text('পরিশোধিত: ৳ ${sale.paidAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
              Text('বকেয়া পাওনা: ৳ ${sale.dueAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
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
}
