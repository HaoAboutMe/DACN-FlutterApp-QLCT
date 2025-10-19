import 'package:flutter/material.dart';

/// Color constants used in the HomePage
class HomeColors {
  // Primary colors - Changed to Ocean Blue (Dolphin Blue)
  static const Color primary = Color(0xFF00A8CC); // Ocean Blue - màu xanh nước biển của cá heo
  static const Color primaryDark = Color(0xFF007B9A); // Darker ocean blue

  // Background colors
  static const Color background = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Colors.grey;

  // Status colors
  static const Color income = Color(0xFF00B894); // Ocean green for income
  static const Color expense = Colors.red;
  static const Color loanGiven = Color(0xFF00CEC9); // Turquoise for loans given
  static const Color loanReceived = Color(0xFF74B9FF); // Light blue for loans received

  // Notification badge
  static const Color notificationBadge = Colors.red;

  // Shadow color
  static Color cardShadow = Colors.black.withValues(alpha: 0.08);

  // AppBar colors
  static Color appBarTextSecondary = Colors.white.withValues(alpha: 0.8);
  static Color logoFallback = Colors.white.withValues(alpha: 0.2);

  // Balance card colors
  static Color balanceBackground = primary.withValues(alpha: 0.1);
  static Color balanceBorder = primary.withValues(alpha: 0.2);

  // Stat card colors
  static Color getStatCardBackground(Color color) => color.withValues(alpha: 0.1);
  static Color getStatCardBorder(Color color) => color.withValues(alpha: 0.2);

  // Transaction icon background
  static Color getTransactionIconBackground(Color color) => color.withValues(alpha: 0.1);
}
