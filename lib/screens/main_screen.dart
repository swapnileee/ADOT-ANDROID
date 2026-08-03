import 'dart:ui';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'orders_screen.dart';
import 'expenses_screen.dart';
import 'cash_in_hand_breakdown_screen.dart';
import '../widgets/app_drawer.dart';
import 'net_profit_breakdown_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onNavigateToPOS: () => _navigateToTab(2),
        onNavigateToInventory: () => _navigateToTab(1),
        onNavigateToOrders: () => _navigateToTab(3),
        onNavigateToExpenses: () => _navigateToTab(4),
        onNavigateToCashInHand: () => _navigateToTab(5),
        onNavigateToNetProfit: () => _navigateToTab(6),
        onNavigateToTab: _navigateToTab,
      ),
      const InventoryScreen(),
      const POSScreen(),
      const OrdersScreen(),
      const ExpensesScreen(),
      CashInHandBreakdownScreen(onSelectTab: _navigateToTab),
      NetProfitBreakdownScreen(onSelectTab: _navigateToTab),
    ];
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final int activeTab = _currentIndex > 4 ? 0 : _currentIndex;
    final bool isSelected = activeTab == index;
    const activeColor = Color(0xFF0B4D2C);

    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? activeColor : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF0B4D2C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBody: true,
      drawer: AppDrawer(
        currentTab: _currentIndex,
        onSelectTab: _navigateToTab,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 52,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final int activeTab = _currentIndex > 4 ? 0 : _currentIndex;
                      final double tabWidth = constraints.maxWidth / 5;

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // 1. Floating Animated Sliding Green Pill Indicator
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: activeTab * tabWidth + 3,
                            top: 2,
                            bottom: 2,
                            width: tabWidth - 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                          // 2. Tab Items Row
                          Row(
                            children: [
                              Expanded(child: _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'ড্যাশবোর্ড')),
                              Expanded(child: _buildNavItem(1, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'পণ্য')),
                              Expanded(child: _buildNavItem(2, Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'POS')),
                              Expanded(child: _buildNavItem(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'অর্ডার')),
                              Expanded(child: _buildNavItem(4, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'আরও')),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
