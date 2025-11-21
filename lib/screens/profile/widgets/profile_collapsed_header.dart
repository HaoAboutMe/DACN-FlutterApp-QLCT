import 'package:flutter/material.dart';

/// Header when AppBar is collapsed - Left-aligned like TPBank style
class ProfileCollapsedHeader extends StatelessWidget {
  final bool isDark;
  final String userName;

  const ProfileCollapsedHeader({
    super.key,
    required this.isDark,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Larger avatar (52px) - Similar to TPBank
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D5FEF).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27.5),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person,
                  size: 28,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 14),

        // User name - Larger, clear, left-aligned
        Expanded(
          child: Text(
            userName,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

