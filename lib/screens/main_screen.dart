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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'ড্যাশবোর্ড'),
                    _buildNavItem(1, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'পণ্য'),
                    _buildNavItem(2, Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'POS'),
                    _buildNavItem(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'অর্ডার'),
                    _buildNavItem(4, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'আরও'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
