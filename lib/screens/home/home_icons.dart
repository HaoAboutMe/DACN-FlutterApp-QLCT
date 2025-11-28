import 'package:flutter/material.dart';
import '../../utils/icon_helper.dart';

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

  /// Get icon from string name or codePoint with fallback
  static IconData getIconFromString(String iconName) {
    return IconHelper.getCategoryIcon(iconName);
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
