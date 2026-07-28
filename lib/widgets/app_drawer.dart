import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';
import '../screens/report_screen.dart';
import '../screens/low_stock_screen.dart';
import '../screens/dues_screen.dart';
import '../screens/stock_in_screen.dart';
import '../screens/staff_management_screen.dart';

class AppDrawer extends StatefulWidget {
  final int currentTab;
  final Function(int) onSelectTab;
  final VoidCallback? onRefreshData;

  const AppDrawer({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    this.onRefreshData,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isSyncing = false;
  String _lastSyncTimeText = 'আজ ${DateFormat('h:mm a').format(DateTime.now())}';

  Future<void> _handleDataSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await _supabaseService.fetchDashboardStats();
      if (widget.onRefreshData != null) {
        widget.onRefreshData!();
      }

      if (!mounted) return;
      setState(() {
        _lastSyncTimeText = 'আজ ${DateFormat('h:mm a').format(DateTime.now())}';
      });
      CustomSnackBar.showSuccess(context, 'ডাটা সফলভাবে সিঙ্ক করা হয়েছে!');
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, 'ডাটা সিঙ্ক করতে ব্যর্থ হয়েছে: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _navigateToScreen(Widget screen) {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _selectTab(int tabIndex) {
    Navigator.pop(context); // Close drawer
    widget.onSelectTab(tabIndex);
  }

  void _showComingSoonToast(String featureName) {
    CustomSnackBar.showInfo(context, '$featureName শীঘ্রই যুক্ত হচ্ছে!');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.creamBg,
      child: Column(
        children: [
          // Premium Material 3 Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADOT Organic Store',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Organic Store Management',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Version Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'v1.0.2 • Live Cloud Sync',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Items List (Grouped with subtle spacing)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              children: [
                _buildSectionHeader('মূল নেভিগেশন (MAIN)'),
                _buildDrawerCardItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  title: 'ড্যাশবোর্ড',
                  subtitle: 'সার্বিক বিক্রয় ও ব্যবসার ওভারভিউ',
                  isSelected: widget.currentTab == 0,
                  onTap: () => _selectTab(0),
                ),
                _buildDrawerCardItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  title: 'পণ্য সমূহ',
                  subtitle: 'পণ্য ও ইনভেন্টরি স্টক',
                  isSelected: widget.currentTab == 1,
                  onTap: () => _selectTab(1),
                ),
                _buildDrawerCardItem(
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale_rounded,
                  title: 'বিক্রি ও POS',
                  subtitle: 'দ্রুত ক্যাশ মেমো ও বিলিং',
                  isSelected: widget.currentTab == 2,
                  onTap: () => _selectTab(2),
                ),

                const SizedBox(height: 12),
                _buildSectionHeader('স্টোর ও হিসাব (MANAGEMENT)'),
                _buildDrawerCardItem(
                  icon: Icons.move_to_inbox_outlined,
                  activeIcon: Icons.move_to_inbox_rounded,
                  title: 'ক্রয় / স্টক ইন',
                  subtitle: 'নতুন স্টক ও ক্রয় হিসেব',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const StockInScreen()),
                ),
                _buildDrawerCardItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  title: 'বকেয়া খাতা',
                  subtitle: 'গ্রাহকদের বকেয়া ও বাকি খাতা',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const DuesScreen()),
                ),
                _buildDrawerCardItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  title: 'দৈনন্দিন খরচ',
                  subtitle: 'দোকানের বায় ও খরচ হিসাব',
                  isSelected: widget.currentTab == 4,
                  onTap: () => _selectTab(4),
                ),
                _buildDrawerCardItem(
                  icon: Icons.badge_outlined,
                  activeIcon: Icons.badge_rounded,
                  title: 'কর্মচারী ব্যবস্থাপনা',
                  subtitle: 'স্টাফ ও বেতন হিসাব',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const StaffManagementScreen()),
                ),

                const SizedBox(height: 12),
                _buildSectionHeader('রিপোর্ট ও সেটিংস (SYSTEM)'),
                _buildDrawerCardItem(
                  icon: Icons.assessment_outlined,
                  activeIcon: Icons.assessment_rounded,
                  title: 'রিপোর্ট ও অ্যানালিটিক্স',
                  subtitle: 'লাভ-ক্ষতি ও সেলস রিপোর্ট',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const ReportScreen()),
                ),
                _buildDrawerCardItem(
                  icon: Icons.notifications_active_outlined,
                  activeIcon: Icons.notifications_active_rounded,
                  title: 'কম স্টকের অ্যালার্ট',
                  subtitle: 'জরুরী রি-অর্ডার পণ্য',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const LowStockScreen()),
                  badgeText: 'অ্যালার্ট',
                  badgeColor: AppTheme.errorRed,
                ),
                _buildDrawerCardItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  title: 'সেটিংস',
                  subtitle: 'অ্যাপ ও প্রিন্টার কনফিগারেশন',
                  isSelected: false,
                  onTap: () => _showComingSoonToast('সেটিংস'),
                ),
                _buildDrawerCardItem(
                  icon: Icons.cloud_sync_outlined,
                  activeIcon: Icons.cloud_sync_rounded,
                  title: 'ডেটা সিঙ্ক',
                  subtitle: 'ক্লাউড ডেটা রিয়েলটাইম সিঙ্ক',
                  isSelected: false,
                  onTap: _handleDataSync,
                ),
              ],
            ),
          ),

          // Drawer Footer & Full-Width Sync Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTheme.cardBorderColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _handleDataSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isSyncing
                        ? const SpinKitThreeBounce(color: Colors.white, size: 16)
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      _isSyncing ? 'সিঙ্ক হচ্ছে...' : '☁️ ডেটা সিঙ্ক করুন',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'সর্বশেষ সিঙ্ক: $_lastSyncTimeText',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADOT Digital Khata App',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'v1.0.2 Build',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDrawerCardItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.3) : AppTheme.cardBorderColor,
          width: isSelected ? 1.5 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryGreen.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Animated Icon Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.lightGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? Colors.white : AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle Hierarchy
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.8) : AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppTheme.warningOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
