import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/shop_info_service.dart';
import '../services/supabase_service.dart';
import '../models/sale_model.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  double _totalDue = 0.0;
  List<SaleModel> _dueSalesList = [];

  @override
  void initState() {
    super.initState();
    _loadDuesData();
  }

  Future<void> _loadDuesData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _supabaseService.fetchSales();
      double dueSum = 0.0;
      final List<SaleModel> dues = [];

      for (var s in sales) {
        dueSum += s.dueAmount;
        if (s.dueAmount > 0) {
          dues.add(s);
        }
      }

      if (!mounted) return;
      setState(() {
        _dueSalesList = dues;
        _totalDue = dueSum;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomSnackBar.showError(context, 'বকেয়া ডাটা লোড করতে ব্যর্থ: $e');
    }
  }

  Future<void> _sendDirectSms(SaleModel sale) async {
    final String phone = sale.customerPhone?.trim() ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        CustomSnackBar.showError(context, 'গ্রাহকের মোবাইল নম্বর পাওয়া যায়নি!');
      }
      return;
    }

    final String name = sale.customerName.isEmpty ? 'সম্মানিত গ্রাহক' : sale.customerName;
    final String due = sale.dueAmount.toStringAsFixed(0);
    final String shopName = ShopInfoService.shopInfoNotifier.value.name;

    final String message = 'প্রিয় $name, $shopName-এ আপনার বকেয়া পাওনা ৳ $due টাকা। অনুগ্রহ করে বকেয়া পরিশোধ করার জন্য অনুরোধ করা হচ্ছে। ধন্যবাদ!';
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'মেসেজ অ্যাপ খুলতে সমস্যা হয়েছে: $e');
      }
    }
  }

  void _showCollectOrEditDueDialog(SaleModel sale) {
    int selectedMode = 0; // 0 = Collect Payment (Reduce Due), 1 = Add New Credit (Increase Due)
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
                          'বকেয়া খাতা এডিট - ${sale.customerName.isEmpty ? "নগদ ক্রেতা" : sale.customerName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
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
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                      // Mode Selector Chips
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('১. পেমেন্ট গ্রহণ'),
                              selected: selectedMode == 0,
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: AppTheme.creamBg,
                              labelStyle: TextStyle(
                                color: selectedMode == 0 ? Colors.white : AppTheme.textDark,
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
                              selectedColor: AppTheme.warningOrange,
                              backgroundColor: AppTheme.creamBg,
                              labelStyle: TextStyle(
                                color: selectedMode == 1 ? Colors.white : AppTheme.textDark,
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

                      // Input Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedMode == 0 ? 'সংগৃহীত টাকার পরিমাণ (৳) *' : 'অতিরিক্ত বাকির পরিমাণ (৳) *',
                          prefixIcon: Icon(
                            selectedMode == 0 ? Icons.payments_outlined : Icons.add_circle_outline_rounded,
                            color: selectedMode == 0 ? AppTheme.primaryGreen : AppTheme.warningOrange,
                          ),
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

                      // Live Calculation Preview Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('পূর্বের বকেয়া:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                Text('৳ ${sale.dueAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedMode == 0 ? 'নতুন পরিশোধিত:' : 'নতুন বাকিসহ বকেয়া:',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                                Text(
                                  selectedMode == 0 ? '৳ ${previewPaid.toStringAsFixed(0)}' : '৳ ${previewDue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('সমন্বয় পরবর্তী বকেয়া:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(
                                  previewDue <= 0 ? 'পরিশোধিত (৳ 0)' : '৳ ${previewDue.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: previewDue <= 0 ? AppTheme.primaryGreen : AppTheme.errorRed,
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
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              CustomSnackBar.showSuccess(context, 'বকেয়া হিসাব সফলভাবে হালনাগাদ করা হয়েছে!');
                              _loadDuesData();
                            }
                          } catch (e) {
                            if (mounted) {
                              CustomSnackBar.showError(context, 'বকেয়া আপডেট করতে ত্রুটি: $e');
                            }
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: isSaving
                      ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                      : const Text('সংরক্ষণ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        title: const Text('বকেয়া খাতা (Due Management)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDuesData,
            tooltip: 'রিফ্রেশ',
          ),
        ],
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
                onRefresh: _loadDuesData,
                color: AppTheme.primaryGreen,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Summary Metric Banner
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
                            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'বকেয়া খাতা ও দেনা-পাওনা ড্যাশবোর্ড',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'মোট ${_dueSalesList.length}টি বকেয়া হিসাব বাকি রয়েছে',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '৳ ${_totalDue.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'বকেয়া তালিকা (Customer Dues)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_dueSalesList.length}টি পেন্ডিং',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _dueSalesList.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'বর্তমানে কোন বকেয়া পাওনা নেই (সব পরিশোধিত)',
                                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _dueSalesList.length,
                            itemBuilder: (context, index) {
                              final sale = _dueSalesList[index];
                              final dateStr = sale.createdAt != null
                                  ? DateFormat('dd MMM yyyy, h:mm a').format(sale.createdAt!)
                                  : 'আজ';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: AppTheme.warningOrange.withValues(alpha: 0.15),
                                                child: const Icon(Icons.person_outline_rounded, color: AppTheme.warningOrange, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${sale.customerName.isEmpty ? "নগদ ক্রেতা" : sale.customerName}${sale.customerPhone != null && sale.customerPhone!.isNotEmpty ? " (${sale.customerPhone})" : ""}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  Text(
                                                    dateStr,
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'বকেয়া বাকি',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const Divider(height: 20),

                                      Text(
                                        'পণ্য: ${sale.productName}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                                      ),

                                      const SizedBox(height: 10),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('সর্বমোট দাম', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                              Text('৳ ${sale.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('পরিশোধিত', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                              Text('৳ ${sale.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('বর্তমান বকেয়া', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                              Text(
                                                '৳ ${sale.dueAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.errorRed),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: SizedBox(
                                              height: 42,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFD97706),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                                onPressed: () => _sendDirectSms(sale),
                                                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                                                label: const Text(
                                                  'SMS পাঠান',
                                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 1,
                                            child: SizedBox(
                                              height: 42,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF1B4332),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                                onPressed: () => _showCollectOrEditDueDialog(sale),
                                                icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.white),
                                                label: const Text(
                                                  'আদায় / এডিট',
                                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}
