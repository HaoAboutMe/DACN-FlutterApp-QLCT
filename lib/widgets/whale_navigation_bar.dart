import 'package:flutter/material.dart';

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
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A8CC).withValues(alpha: 0.1),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Trang chủ',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.swap_horiz_rounded,
                label: 'Giao dịch',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cho vay',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.bar_chart_rounded,
                label: 'Thống kê',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.person_rounded,
                label: 'Cá nhân',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF00A8CC) : Colors.grey.shade400;

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
              // Icon với hiệu ứng sóng khi được chọn
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
