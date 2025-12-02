import 'package:flutter/material.dart';

/// Header when AppBar is expanded
class ProfileExpandedHeader extends StatelessWidget {
  final bool isDark;
  final double expandRatio;
  final bool isEditingName;
  final String userName;
  final TextEditingController nameController;
  final VoidCallback onSaveName;
  final VoidCallback onCancelEdit;

  const ProfileExpandedHeader({
    super.key,
    required this.isDark,
    required this.expandRatio,
    required this.isEditingName,
    required this.userName,
    required this.nameController,
    required this.onSaveName,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic size based on expandRatio
    final double avatarSize = 70 + (expandRatio * 30); // 70-100
    final double nameFontSize = 15 + (expandRatio * 4); // 15-19

    return Container(
      padding: const EdgeInsets.only(
        top: 40,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with logo - dynamic size
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D5FEF).withValues(alpha: 0.3 * expandRatio),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      size: avatarSize * 0.5,
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // User name or editing TextField
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isEditingName
                  ? SizedBox(
                width: 260,
                child: TextField(
                  controller: nameController,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  maxLength: 30,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                    isDense: true,
                    counterText: '',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green, size: 18),
                          onPressed: onSaveName,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 18),
                          onPressed: onCancelEdit,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF5D5FEF), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              )
                  : AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                child: Text(
                  userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

