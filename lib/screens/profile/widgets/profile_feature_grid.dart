import 'package:flutter/material.dart';
import 'profile_feature_card.dart';

/// Grid of main features
class ProfileFeatureGrid extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onNavigateToCategoryManagement;
  final VoidCallback onNavigateToBudgetManagement;
  final VoidCallback onShowReminderDialog;
  final Function(String) onShowFeatureSnackbar;

  const ProfileFeatureGrid({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onNavigateToCategoryManagement,
    required this.onNavigateToBudgetManagement,
    required this.onShowReminderDialog,
    required this.onShowFeatureSnackbar,
  });

  @override
  Widget build(BuildContext context) {
    final features = [
      {
        'icon': Icons.notifications,
        'title': 'Thông báo\nnhắc nhở',
        'color': const Color(0xFF4ECDC4),
      },
      {
        'icon': isDark ? Icons.light_mode : Icons.dark_mode,
        'title': 'Chế độ\n${isDark ? 'sáng' : 'tối'}',
        'color': const Color(0xFF00A8CC),
        'isToggle': true,
      },
      {
        'icon': Icons.category,
        'title': 'Tùy chỉnh\ndanh mục',
        'color': const Color(0xFFFF6B6B),
        'isCategoryManagement': true,
      },

    ];

    return Container(
      margin: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: 0,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          return ProfileFeatureCard(
            icon: feature['icon'] as IconData,
            title: feature['title'] as String,
            color: feature['color'] as Color,
            isDark: isDark,
            onTap: () {
              if (feature['isToggle'] == true) {
                onToggleTheme();
              } else if (feature['isCategoryManagement'] == true) {
                onNavigateToCategoryManagement();
              } else if (feature['title'] == 'Thông báo\nnhắc nhở') {
                onShowReminderDialog();
              } else {
                onShowFeatureSnackbar(feature['title'] as String);
              }
            },
          );
        },
      ),
    );
  }
}

