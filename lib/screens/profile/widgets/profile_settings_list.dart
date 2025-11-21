import 'package:flutter/material.dart';

class ProfileSettingsList extends StatelessWidget {
  final bool isDark;
  final String selectedCurrency;
  final Function(String?) onChangeCurrency;
  final VoidCallback onShowReminderDialog;
  final VoidCallback onWidgetSettingTap;
  final VoidCallback onNavigateToAbout;
  final VoidCallback onNavigateToUserGuide;
  final VoidCallback onManageShortcutsTap;
  final Function(String) onShowFeatureSnackbar;
  final bool supportsAndroidWidget;
  final bool isWidgetPinned;
  final bool isRequestingWidget;

  const ProfileSettingsList({
    super.key,
    required this.isDark,
    required this.selectedCurrency,
    required this.onChangeCurrency,
    required this.onShowReminderDialog,
    required this.onWidgetSettingTap,
    required this.onNavigateToAbout,
    required this.onNavigateToUserGuide,
    required this.onManageShortcutsTap,
    required this.onShowFeatureSnackbar,
    required this.supportsAndroidWidget,
    required this.isWidgetPinned,
    required this.isRequestingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final settings = [
      {
        'icon': Icons.widgets_outlined,
        'title': 'Thêm Widget',
        'subtitle': 'Tùy chỉnh widget trên màn hình chính',
      },
      {
        'icon': Icons.touch_app,
        'title': 'Quản lý phím tắt',
        'subtitle': 'Tùy chỉnh phím tắt nhanh',
      },
      {
        'icon': Icons.help_outline,
        'title': 'Hướng dẫn sử dụng',
        'subtitle': 'Hướng dẫn chi tiết cách sử dụng ứng dụng',
      },
      {
        'icon': Icons.attach_money_outlined,
        'title': 'Tùy chọn loại tiền',
        'subtitle': 'Chọn đơn vị tiền tệ mặc định',
      },
      {
        'icon': Icons.info_outline,
        'title': 'Về chúng tôi',
        'subtitle': 'Thông tin về đội ngũ phát triển',
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...settings.asMap().entries.map((entry) {
            final index = entry.key;
            final setting = entry.value;
            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                _buildSettingTile(context, setting),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, Map<String, dynamic> setting) {
    // Widget setting
    if (setting['title'] == 'Thêm Widget') {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            setting['icon'] as IconData,
            color: const Color(0xFF5D5FEF),
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
          setting['subtitle'] as String,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: supportsAndroidWidget
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWidgetPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Đã thêm',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (isRequestingWidget)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                ],
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
        onTap: onWidgetSettingTap,
      );
    }

    // Currency setting
    if (setting['title'] == 'Tùy chọn loại tiền') {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            setting['icon'] as IconData,
            color: const Color(0xFF5D5FEF),
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
          setting['subtitle'] as String,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: selectedCurrency,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: const [
              DropdownMenuItem(
                value: 'VND',
                child: Text('VND (₫)'),
              ),
              DropdownMenuItem(
                value: 'USD',
                child: Text('USD (\$)'),
              ),
            ],
            onChanged: onChangeCurrency,
          ),
        ),
      );
    }

    // Default setting tile
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          setting['icon'] as IconData,
          color: const Color(0xFF5D5FEF),
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
        setting['subtitle'] as String,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
      onTap: setting['title'] == 'Về chúng tôi'
          ? onNavigateToAbout
          : setting['title'] == 'Hướng dẫn sử dụng'
          ? onNavigateToUserGuide
          : setting['title'] == 'Quản lý phím tắt'
          ? onManageShortcutsTap
          : () => onShowFeatureSnackbar(setting['title'] as String),
    );
  }
}

