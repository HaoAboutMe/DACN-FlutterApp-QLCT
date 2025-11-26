import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_badge.dart';
import '../home_colors.dart';
import '../home_icons.dart';

class GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final VoidCallback onNotificationPressed;
  final VoidCallback? onScanPressed;

  const GreetingAppBar({
    super.key,
    this.currentUser,
    required this.onNotificationPressed,
    this.onScanPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark
        ? const Color(0xFF2d3a4a) // Dark: Màu cá voi sát thủ
        : Theme.of(context).colorScheme.primary, // Light: Xanh biển
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildAppLogo(context),
              const SizedBox(width: 12),
              _buildGreetingText(),
              if (onScanPressed != null) ...[
                _buildScanButton(context),
                const SizedBox(width: 8),
              ],
              _buildNotificationButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              HomeIcons.wallet,
              color: Colors.white,
              size: 20,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingText() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Xin chào, ${currentUser?.name ?? 'bạn'}!',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Quản lý chi tiêu Whales Spent',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: NotificationBadge(
              count: unreadCount,
              showCount: true,
              badgeColor: HomeColors.notificationBadge,
              child: const Icon(
                HomeIcons.notification,
                color: Colors.white,
                size: 22,
              ),
            ),
            onPressed: onNotificationPressed,
          ),
        );
      },
    );
  }

  Widget _buildScanButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.document_scanner_rounded,
          color: Colors.white,
          size: 22,
        ),
        onPressed: onScanPressed,
        tooltip: 'Quét hóa đơn',
      ),
    );
  }
}
