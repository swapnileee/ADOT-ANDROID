import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';
import '../screens/report_screen.dart';
import '../screens/low_stock_screen.dart';

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

  Future<void> _handleDataSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      // Sync/refetch all Supabase data
      await _supabaseService.fetchDashboardStats();
      if (widget.onRefreshData != null) {
        widget.onRefreshData!();
      }

      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.creamBg,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
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
                        color: AppTheme.accentGold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppTheme.accentGold,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADOT | আদত',
                            style: TextStyle(
                              color: AppTheme.accentGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'স্টোর ক্যাশিয়ার',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ডিজিটাল খাতা ও স্টোর ব্যবস্থাপনা',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  title: 'ড্যাশবোর্ড',
                  subtitle: 'সার্বিক বিক্রয় ও হিসাব',
                  isSelected: widget.currentTab == 0,
                  onTap: () => _selectTab(0),
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  title: 'পণ্য ও ইনভেন্টরি',
                  subtitle: 'পণ্য তালিকা ও স্টক ব্যবস্থাপনা',
                  isSelected: widget.currentTab == 3,
                  onTap: () => _selectTab(3),
                ),
                _buildDrawerItem(
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale_rounded,
                  title: 'বিক্রি ও অর্ডার',
                  subtitle: 'নতুন ক্যাশ মেমো ও বিক্রি',
                  isSelected: widget.currentTab == 1,
                  onTap: () => _selectTab(1),
                ),
                _buildDrawerItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  title: 'দৈনন্দিন খরচ',
                  subtitle: 'দোকানের বায় ও খরচ হিসাব',
                  isSelected: widget.currentTab == 2,
                  onTap: () => _selectTab(2),
                ),
                const Divider(height: 24, indent: 16, endIndent: 16),
                _buildDrawerItem(
                  icon: Icons.assessment_outlined,
                  activeIcon: Icons.assessment_rounded,
                  title: 'সেলস ও হিসাব রিপোর্ট',
                  subtitle: 'আয়-ব্যয় ও লাভ-ক্ষতির রিপোর্ট',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const ReportScreen()),
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_active_outlined,
                  activeIcon: Icons.notifications_active_rounded,
                  title: 'কম স্টকের অ্যালার্ট',
                  subtitle: 'কম স্টক থাকা পণ্যের তালিকা',
                  isSelected: false,
                  onTap: () => _navigateToScreen(const LowStockScreen()),
                  badgeText: 'অ্যালার্ট',
                  badgeColor: AppTheme.errorRed,
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _handleDataSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSyncing
                        ? const SpinKitThreeBounce(color: Colors.white, size: 16)
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      _isSyncing ? 'সিঙ্ক হচ্ছে...' : '🔄 ডাটা সিঙ্ক করুন',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADOT App',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'v1.0.2',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
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

  Widget _buildDrawerItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark.withValues(alpha: 0.7),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.8) : AppTheme.textMuted,
                ),
              )
            : null,
        trailing: badgeText != null
            ? Container(
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
              )
            : null,
      ),
    );
  }
}
