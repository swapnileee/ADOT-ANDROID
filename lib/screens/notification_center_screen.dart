import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_snackbar.dart';

enum NotificationType { all, urgent, pending, info, read }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final NotificationType type;
  final String actionText;
  final IconData icon;
  final VoidCallback? onAction;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.type,
    required this.actionText,
    required this.icon,
    this.onAction,
    this.isRead = false,
  });

  String get categoryName {
    switch (type) {
      case NotificationType.urgent:
        return 'জরুরি';
      case NotificationType.pending:
        return 'অপেক্ষমাণ';
      case NotificationType.info:
        return 'তথ্য';
      case NotificationType.read:
      case NotificationType.all:
        return 'সাধারণ';
    }
  }

  Color get borderAccentColor {
    if (isRead) return const Color(0xFF2E7D32);
    switch (type) {
      case NotificationType.urgent:
        return const Color(0xFFD32F2F);
      case NotificationType.pending:
        return const Color(0xFFEF6C00);
      case NotificationType.info:
        return const Color(0xFF1565C0);
      case NotificationType.read:
      case NotificationType.all:
        return const Color(0xFF2E7D32);
    }
  }

  Color get iconBgColor {
    if (isRead) return const Color(0xFFE8F5E9);
    switch (type) {
      case NotificationType.urgent:
        return const Color(0xFFFFEBEE);
      case NotificationType.pending:
        return const Color(0xFFFFF3E0);
      case NotificationType.info:
        return const Color(0xFFE3F2FD);
      case NotificationType.read:
      case NotificationType.all:
        return const Color(0xFFE8F5E9);
    }
  }
}

class NotificationCenterScreen extends StatefulWidget {
  final List<AppNotification>? notifications;

  const NotificationCenterScreen({
    super.key,
    this.notifications,
  });

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  static const Color primaryDarkGreen = Color(0xFF1E4D3B);
  static const Color bgLightGray = Color(0xFFF8F9FA);
  static const Color cardBorderColor = Color(0xFFE5E7EB);

  NotificationType selectedFilter = NotificationType.all;

  late List<AppNotification> _list;

  @override
  void initState() {
    super.initState();
    _list = widget.notifications ?? [];
  }

  int get _urgentCount => _list.where((n) => n.type == NotificationType.urgent && !n.isRead).length;
  int get _pendingCount => _list.where((n) => n.type == NotificationType.pending && !n.isRead).length;
  int get _infoCount => _list.where((n) => n.type == NotificationType.info && !n.isRead).length;
  int get _readCount => _list.where((n) => n.isRead).length;
  int get unreadCount => _list.where((n) => !n.isRead).length;

  List<AppNotification> get filteredList {
    if (selectedFilter == NotificationType.urgent) {
      return _list.where((n) => n.type == NotificationType.urgent && !n.isRead).toList();
    }
    if (selectedFilter == NotificationType.pending) {
      return _list.where((n) => n.type == NotificationType.pending && !n.isRead).toList();
    }
    if (selectedFilter == NotificationType.info) {
      return _list.where((n) => n.type == NotificationType.info && !n.isRead).toList();
    }
    if (selectedFilter == NotificationType.read) {
      return _list.where((n) => n.isRead).toList();
    }
    return _list;
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _list) {
        item.isRead = true;
      }
    });
    CustomSnackBar.showSuccess(context, 'সকল নোটিফিকেশন পড়া হয়েছে হিসেবে চিহ্নিত করা হয়েছে!');
  }

  void _popWithResult() {
    Navigator.pop(context, unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = filteredList;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithResult();
      },
      child: Scaffold(
        backgroundColor: bgLightGray,
        appBar: AppBar(
          backgroundColor: primaryDarkGreen,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _popWithResult,
          ),
          title: const Text(
            'নোটিফিকেশন সেন্টার',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 24),
                  onPressed: () {},
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTopFilterCardsRow(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: displayItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'কোনো নোটিফিকেশন নেই',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          return _buildNotificationCard(item);
                        },
                      ),
              ),
              _buildBottomActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopFilterCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterCard(
            title: 'জরুরি',
            count: _urgentCount,
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFD32F2F),
            bgColor: const Color(0xFFFFEBEE),
            targetType: NotificationType.urgent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterCard(
            title: 'অপেক্ষমাণ',
            count: _pendingCount,
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFEF6C00),
            bgColor: const Color(0xFFFFF3E0),
            targetType: NotificationType.pending,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterCard(
            title: 'তথ্য',
            count: _infoCount,
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF1565C0),
            bgColor: const Color(0xFFE3F2FD),
            targetType: NotificationType.info,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFilterCard(
            title: 'পড়া হয়েছে',
            count: _readCount,
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFE8F5E9),
            targetType: NotificationType.read,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required NotificationType targetType,
  }) {
    final isSelected = selectedFilter == targetType;

    return InkWell(
      onTap: () {
        setState(() {
          if (selectedFilter == targetType) {
            selectedFilter = NotificationType.all;
          } else {
            selectedFilter = targetType;
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? iconColor : cardBorderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? iconColor : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? iconColor : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    String label = 'সাম্প্রতিক নোটিফিকেশন';
    if (selectedFilter == NotificationType.urgent) label = 'নোটিফিকেশন: জরুরি';
    if (selectedFilter == NotificationType.pending) label = 'নোটিফিকেশন: অপেক্ষমাণ';
    if (selectedFilter == NotificationType.info) label = 'নোটিফিকেশন: তথ্য';
    if (selectedFilter == NotificationType.read) label = 'নোটিফিকেশন: পড়া হয়েছে';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryDarkGreen,
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              selectedFilter = NotificationType.all;
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'সব দেখুন >',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: primaryDarkGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(AppNotification item) {
    final accent = item.borderAccentColor;
    final iconBg = item.iconBgColor;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: item.isRead ? const Color(0xFFFAFAFA) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: cardBorderColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: accent, width: 5),
          ),
        ),
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: item.isRead ? Colors.grey.shade700 : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.3,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.categoryName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      item.isRead = true;
                    });
                    if (item.onAction != null) {
                      item.onAction!();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Text(
                    item.actionText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  label: Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: cardBorderColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _markAllAsRead,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryDarkGreen, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.check_circle_outline, color: primaryDarkGreen, size: 20),
          label: const Text(
            'সব পড়া হয়েছে',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryDarkGreen),
          ),
        ),
      ),
    );
  }
}
