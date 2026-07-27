import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'orders_screen.dart';
import 'expenses_screen.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToPOS: () => _navigateToTab(2),
        onNavigateToInventory: () => _navigateToTab(1),
      ),
      const InventoryScreen(),
      const POSScreen(),
      const OrdersScreen(),
      const ExpensesScreen(),
    ];

    return Scaffold(
      drawer: AppDrawer(
        currentTab: _currentIndex,
        onSelectTab: _navigateToTab,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.cardBorderColor, width: 1)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'ড্যাশবোর্ড',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'পণ্য',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale_outlined),
                activeIcon: Icon(Icons.point_of_sale_rounded),
                label: 'POS',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'অর্ডার',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_rounded),
                activeIcon: Icon(Icons.more_horiz_rounded),
                label: 'আরও',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
