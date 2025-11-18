import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final double amount;
  final IconData icon;
  final Color color;
  final double percentage;

  ExpenseCategory({
    required this.name,
    required this.amount,
    required this.icon,
    required this.color,
    required this.percentage,
  });

  ExpenseCategory copyWith({
    String? name,
    double? amount,
    IconData? icon,
    Color? color,
    double? percentage,
  }) {
    return ExpenseCategory(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      percentage: percentage ?? this.percentage,
    );
  }
}

