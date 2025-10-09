import 'package:flutter/material.dart';

/// Icon constants and utilities used in the HomePage
class HomeIcons {
  // App navigation icons
  static const IconData notification = Icons.notifications_outlined;
  static const IconData wallet = Icons.account_balance_wallet;

  // Visibility toggle
  static const IconData visible = Icons.visibility;
  static const IconData hidden = Icons.visibility_off;

  // Quick action icons
  static const IconData income = Icons.trending_up;
  static const IconData expense = Icons.trending_down;
  static const IconData loanGiven = Icons.call_made;
  static const IconData loanReceived = Icons.call_received;

  // Transaction type icons
  static const IconData payment = Icons.payment;
  static const IconData accountBalance = Icons.account_balance_wallet;
  static const IconData swapHoriz = Icons.swap_horiz;

  // Empty state icon
  static const IconData receiptLong = Icons.receipt_long_outlined;

  // Category icons mapping
  static const Map<String, IconData> categoryIcons = {
    'restaurant': Icons.restaurant,
    'food': Icons.restaurant,
    'transport': Icons.directions_car,
    'directions_car': Icons.directions_car,
    'shopping_cart': Icons.shopping_cart,
    'shopping_bag': Icons.shopping_bag,
    'shopping': Icons.shopping_cart,
    'home': Icons.home,
    'medical_services': Icons.medical_services,
    'health': Icons.medical_services,
    'school': Icons.school,
    'education': Icons.school,
    'work': Icons.work,
    'business': Icons.work,
    'savings': Icons.savings,
    'entertainment': Icons.movie,
    'movie': Icons.movie,
    'travel': Icons.flight,
    'flight': Icons.flight,
    'utilities': Icons.electrical_services,
    'electrical_services': Icons.electrical_services,
    'attach_money': Icons.attach_money,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'fitness_center': Icons.fitness_center,
    'more_horiz': Icons.more_horiz,
    'other': Icons.category,
    'category': Icons.category,
  };

  /// Get icon from string name or codePoint with fallback
  static IconData getIconFromString(String iconName) {
    // Handle empty or null icon names
    if (iconName.isEmpty) {
      return Icons.category;
    }

    // Try to parse as codePoint first (for newer categories created via category picker)
    final codePoint = int.tryParse(iconName);
    if (codePoint != null) {
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    }

    // If not a codePoint, use string mapping (for default categories)
    return categoryIcons[iconName.toLowerCase()] ?? Icons.category;
  }

  /// Get transaction type icon based on type
  static IconData getTransactionTypeIcon(String transactionType) {
    switch (transactionType) {
      case 'income':
        return income;
      case 'expense':
        return expense;
      case 'loan_given':
        return loanGiven;
      case 'loan_received':
        return loanReceived;
      case 'debt_paid':
        return payment;
      case 'debt_collected':
        return accountBalance;
      default:
        return swapHoriz;
    }
  }
}
