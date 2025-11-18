import 'package:flutter/material.dart';

/// Widget setting tile for profile settings
class ProfileWidgetSettingTile extends StatelessWidget {
  final Map<String, dynamic> setting;
  final bool supportsAndroidWidget;
  final bool isWidgetPinned;
  final bool isRequestingWidget;
  final VoidCallback onTap;

  const ProfileWidgetSettingTile({
    super.key,
    required this.setting,
    required this.supportsAndroidWidget,
    required this.isWidgetPinned,
    required this.isRequestingWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF5D5FEF);
    final subtitleText = !supportsAndroidWidget
        ? 'Tính năng này hiện chỉ hỗ trợ Android'
        : isWidgetPinned
        ? 'Widget đã hiển thị trên màn hình chính'
        : setting['subtitle'] as String;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          setting['icon'] as IconData,
          color: accentColor,
          size: 20,
        ),
      ),
      title: Text(
        setting['title'] as String,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitleText,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: isRequestingWidget
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : isWidgetPinned
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Đã thêm',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E7D32),
          ),
        ),
      )
          : Icon(
        Icons.add_circle_outline,
        size: 20,
        color: accentColor,
      ),
      onTap: supportsAndroidWidget ? onTap : null,
    );
  }
}

