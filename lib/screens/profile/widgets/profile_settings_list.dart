import 'package:flutter/material.dart';

/// Settings list widget for profile screen
class ProfileSettingsList extends StatelessWidget {
  final bool isDark;
  final bool supportsAndroidWidget;
  final bool isWidgetPinned;
  final bool isRequestingWidget;
  final String selectedCurrency;
  final Function(Map<String, dynamic>) onBuildWidgetSettingTile;
  final Function(String?) onChangeCurrency;
  final Function(String) onShowFeatureSnackbar;

  const ProfileSettingsList({
    super.key,
    required this.isDark,
    required this.supportsAndroidWidget,
    required this.isWidgetPinned,
    required this.isRequestingWidget,
    required this.selectedCurrency,
    required this.onBuildWidgetSettingTile,
    required this.onChangeCurrency,
    required this.onShowFeatureSnackbar,
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
        'icon': Icons.language_outlined,
        'title': 'Tùy chọn ngôn ngữ',
        'subtitle': 'Thay đổi ngôn ngữ hiển thị',
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
      {
        'icon': Icons.system_update_outlined,
        'title': 'Phiên bản cập nhật',
        'subtitle': 'Kiểm tra phiên bản mới nhất',
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
            offset: const Offset(0, 4),
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
                // Special handling for currency selection
                if (setting['title'] == 'Thêm Widget')
                  onBuildWidgetSettingTile(setting)
                else if (setting['title'] == 'Tùy chọn loại tiền')
                  ListTile(
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
                  )
                else
                  ListTile(
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
                    onTap: () => onShowFeatureSnackbar(setting['title'] as String),
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

