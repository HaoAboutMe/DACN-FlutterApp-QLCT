import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

/// Custom Navigation Bar với theme "cá voi" - bo tròn, tone xanh biển
/// Hỗ trợ animation ẩn/hiện khi scroll
class WhaleNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isVisible;

  const WhaleNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    // Lấy bottom padding từ MediaQuery để xử lý notch/safe area
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        opacity: isVisible ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
              ? const Color(0xFF2d3a4a) // Màu cá voi sát thủ
              : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFF00A8CC).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          // Padding bao gồm cả bottom safe area
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: bottomPadding > 0 ? bottomPadding : 8,
          ),
          child: Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final upcomingLoansCount = notificationProvider.upcomingLoansCount;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context: context,
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'Trang chủ',
                    badgeCount: 0,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 1,
                    icon: Icons.swap_horiz_rounded,
                    label: 'Giao dịch',
                    badgeCount: 0,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 2,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Cho vay',
                    badgeCount: upcomingLoansCount,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 3,
                    icon: Icons.bar_chart_rounded,
                    label: 'Thống kê',
                    badgeCount: 0,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 4,
                    icon: Icons.person_rounded,
                    label: 'Cá nhân',
                    badgeCount: 0,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final color = isSelected
      ? primaryColor
      : (isDark ? Colors.grey.shade400 : Colors.grey.shade500);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon với hiệu ứng sóng khi được chọn và badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.all(isSelected ? 8 : 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00A8CC).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedScale(
                      scale: isSelected ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ),
                  // Badge
                  if (badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2d3a4a) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Label với animation fade
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSelected ? 12 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
