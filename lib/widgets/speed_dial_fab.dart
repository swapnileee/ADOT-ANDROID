import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpeedDialFab extends StatefulWidget {
  final VoidCallback onNewSale;
  final VoidCallback onAddProduct;
  final VoidCallback onAddExpense;

  const SpeedDialFab({
    super.key,
    required this.onNewSale,
    required this.onAddProduct,
    required this.onAddExpense,
  });

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleOption(VoidCallback callback) {
    _toggle();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          _buildSpeedDialOption(
            icon: Icons.add_shopping_cart_rounded,
            label: 'নতুন বিক্রি',
            color: AppTheme.primaryGreen,
            onTap: () => _handleOption(widget.onNewSale),
          ),
          const SizedBox(height: 10),
          _buildSpeedDialOption(
            icon: Icons.add_box_rounded,
            label: 'নতুন পণ্য',
            color: AppTheme.accentGold,
            textColor: AppTheme.darkGreen,
            onTap: () => _handleOption(widget.onAddProduct),
          ),
          const SizedBox(height: 10),
          _buildSpeedDialOption(
            icon: Icons.money_off_rounded,
            label: 'নতুন খরচ',
            color: AppTheme.errorRed,
            onTap: () => _handleOption(widget.onAddExpense),
          ),
          const SizedBox(height: 14),
        ],
        FloatingActionButton(
          heroTag: 'speed_dial_main_fab',
          onPressed: _toggle,
          backgroundColor: _isOpen ? AppTheme.darkGreen : AppTheme.primaryGreen,
          elevation: 6,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: FadeTransition(
        opacity: _expandAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              heroTag: 'fab_option_$label',
              onPressed: onTap,
              backgroundColor: color,
              child: Icon(icon, color: textColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
