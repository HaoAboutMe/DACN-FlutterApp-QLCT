import 'package:flutter/material.dart';

/// Footer widget for profile screen
class ProfileFooter extends StatelessWidget {
  final bool isDark;

  const ProfileFooter({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Whales Spent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF00A8CC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phiên bản 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🐋 Quản lý chi tiêu thông minh',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

