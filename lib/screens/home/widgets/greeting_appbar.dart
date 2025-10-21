import 'package:flutter/material.dart';
import '../../../models/user.dart';
import '../home_colors.dart';
import '../home_icons.dart';

class GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final VoidCallback onNotificationPressed;

  const GreetingAppBar({
    super.key,
    this.currentUser,
    required this.onNotificationPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: HomeColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildAppLogo(),
              const SizedBox(width: 12),
              _buildGreetingText(),
              _buildNotificationButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        'assets/images/whales-spent-logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: HomeColors.logoFallback,
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

  Widget _buildNotificationButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Stack(
          children: [
            const Icon(
              HomeIcons.notification,
              color: Colors.white,
              size: 22,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: HomeColors.notificationBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        onPressed: onNotificationPressed,
      ),
    );
  }
}
