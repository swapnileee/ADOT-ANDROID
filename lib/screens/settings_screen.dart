import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/shop_info_service.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isSyncing = false;
  String _lastSyncTimeText = 'আজ ${DateFormat('h:mm a').format(DateTime.now())}';

  // Notification Toggles State
  bool _isLowStockAlertEnabled = true;
  bool _isDueAlertEnabled = true;

  Future<void> _handleDataSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await _supabaseService.fetchDashboardStats();

      if (!mounted) return;
      setState(() {
        _lastSyncTimeText = 'আজ ${DateFormat('h:mm a').format(DateTime.now())}';
      });
      CustomSnackBar.showSuccess(context, 'ডাটা সফলভাবে ক্লাউডে সিঙ্ক করা হয়েছে!');
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'ডাটা সিঙ্ক করতে সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<bool?> _showEditStoreProfileModal() async {
    final currentInfo = ShopInfoService.shopInfoNotifier.value;
    final nameController = TextEditingController(text: currentInfo.name);
    final phoneController = TextEditingController(text: currentInfo.phone);
    final addressController = TextEditingController(text: currentInfo.address);
    final footerController = TextEditingController(text: currentInfo.invoiceFooter);
    String selectedLogoPath = currentInfo.logoPath;
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final logoImg = ShopInfoService.buildShopLogoImage(selectedLogoPath);
            final hasLogo = logoImg != null;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
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
                            const Text(
                              'দোকানের তথ্য সম্পাদনা',
                              style: TextStyle(
                                fontSize: 18,
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
                        const SizedBox(height: 12),
                        // Prominent circular avatar container for logo
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              try {
                                final croppedPath = await ShopInfoService.pickAndCropLogo();
                                if (croppedPath != null) {
                                  setModalState(() {
                                    selectedLogoPath = croppedPath;
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ছবি নির্বাচন করতে সমস্যা হয়েছে। অ্যাপটি রিস্টার্ট করে চেষ্টা করুন।'),
                                      backgroundColor: AppTheme.errorRed,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    border: Border.all(color: AppTheme.primaryGreen, width: 2),
                                    image: hasLogo
                                        ? DecorationImage(
                                            image: logoImg,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: hasLogo
                                      ? null
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 40,
                                          color: AppTheme.primaryGreen,
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'দোকানের লোগো পরিবর্তন করতে ট্যাপ করুন',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'দোকানের নাম *',
                            prefixIcon: const Icon(Icons.storefront_rounded, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'নাম লিখুন' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'ফোন নম্বর',
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: InputDecoration(
                            labelText: 'ঠিকানা',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: footerController,
                          decoration: InputDecoration(
                            labelText: 'ইনভয়েস নিচের শুভেচ্ছা বার্তা',
                            hintText: 'যেমন: আবার আসবেন, ধন্যবাদ!',
                            prefixIcon: const Icon(Icons.receipt_long_outlined, color: AppTheme.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);

                                // 1. Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const Center(
                                    child: SpinKitFadingCube(color: AppTheme.primaryGreen, size: 40),
                                  ),
                                );

                                try {
                                  // 2. Perform save operation (awaiting local and Supabase sync)
                                  await ShopInfoService.updateShopInfo(
                                    name: nameController.text,
                                    phone: phoneController.text,
                                    address: addressController.text,
                                    invoiceFooter: footerController.text,
                                    logoPath: selectedLogoPath,
                                  );

                                  // 3. Immediately re-fetch and update local cache/notifiers
                                  await ShopInfoService.loadShopInfo();

                                  // 4. Remove loading dialog
                                  nav.pop();

                                  // 5. Force close the BottomSheet modal with result true
                                  nav.pop(true);

                                  // 5. Show success snackbar
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('দোকানের তথ্য ও লোগো সংরক্ষণ করা হয়েছে!'),
                                      backgroundColor: const Color(0xFF1B4332),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                } catch (e) {
                                  // Close loading dialog if open
                                  nav.pop();

                                  // Show meaningful error SnackBar and keep modal open
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('ডাটা সেভ হতে সমস্যা হয়েছে: সুপাবেস ডাটাবেজের সমস্যা বা ইন্টারনেট কানেকশন চেক করুন। Error: $e'),
                                      backgroundColor: AppTheme.errorRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'সংরক্ষণ করুন',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'সেটিংস ও কনফিগারেশন',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Data & Sync
          _buildSectionHeader('ডেটা ও সিঙ্ক সেটিংস'),
          _buildCardGroup([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryGreen, size: 22),
              ),
              title: const Text('লাইভ ক্লাউড সিঙ্ক', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('সর্বশেষ সিঙ্ক: $_lastSyncTimeText', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              trailing: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _isSyncing ? null : _handleDataSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSyncing
                      ? const SpinKitThreeBounce(color: Colors.white, size: 14)
                      : const Text('এখনই সিঙ্ক করুন', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const Divider(height: 1, indent: 60),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sd_storage_rounded, color: Colors.blue, size: 22),
              ),
              title: const Text('অফলাইন ব্যাকআপ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('স্থানীয় ডাটাবেস ব্যাকআপ অবস্থা: সক্রিয়', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              onTap: () => CustomSnackBar.showInfo(context, 'অফলাইন ব্যাকআপ স্থানীয় স্টোরেজে সুরক্ষিত আছে।'),
            ),
          ]),

          const SizedBox(height: 18),

          // Section 2: Store Profile
          _buildSectionHeader('দোকানের তথ্য (Store Profile)'),
          _buildCardGroup([
            ValueListenableBuilder<ShopInfo>(
              valueListenable: ShopInfoService.shopInfoNotifier,
              builder: (context, shopInfo, _) {
                final logoImg = ShopInfoService.buildShopLogoImage(shopInfo.logoPath);
                final hasLogo = logoImg != null;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      image: hasLogo
                          ? DecorationImage(
                              image: logoImg,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasLogo
                        ? null
                        : const Icon(Icons.storefront_rounded, color: AppTheme.primaryGreen, size: 22),
                  ),
                  title: Text(shopInfo.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('ফোন: ${shopInfo.phone} • ${shopInfo.address}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen),
                  onTap: () async {
                    final result = await _showEditStoreProfileModal();
                    if (result == true) {
                      await ShopInfoService.loadShopInfo();
                      if (mounted) setState(() {});
                    }
                  },
                );
              },
            ),
          ]),

          const SizedBox(height: 18),

          // Section 3: Notifications & Alerts
          _buildSectionHeader('নোটিফিকেশন ও অ্যালার্ট'),
          _buildCardGroup([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen, size: 22),
              ),
              title: const Text('কম স্টক নোটিফিকেশন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('পণ্যের স্টক ফুরিয়ে গেলে সতর্কবার্তা দেখাবে', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              value: _isLowStockAlertEnabled,
              activeTrackColor: AppTheme.primaryGreen,
              onChanged: (val) {
                setState(() => _isLowStockAlertEnabled = val);
              },
            ),
            const Divider(height: 1, indent: 60),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, color: Colors.orange, size: 22),
              ),
              title: const Text('বকেয়া রিমাইন্ডার অ্যালার্ট', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('কাস্টমার বকেয়া সংগ্রহের অ্যালার্ট', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              value: _isDueAlertEnabled,
              activeTrackColor: AppTheme.primaryGreen,
              onChanged: (val) {
                setState(() => _isDueAlertEnabled = val);
              },
            ),
          ]),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'ADOT Digital Khata • v1.0.2 Build',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
