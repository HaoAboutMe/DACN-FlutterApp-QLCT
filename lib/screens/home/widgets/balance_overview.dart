import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user.dart';
import '../../../utils/currency_formatter.dart';
import '../home_colors.dart';
import '../home_icons.dart';

class BalanceOverview extends StatefulWidget {
  final User? currentUser;
  final bool isBalanceVisible;
  final VoidCallback onVisibilityToggle;
  final double totalIncome;
  final double totalExpense;
  final double totalLent;
  final double totalBorrowed;

  const BalanceOverview({
    super.key,
    this.currentUser,
    required this.isBalanceVisible,
    required this.onVisibilityToggle,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalLent,
    required this.totalBorrowed,
  });

  @override
  State<BalanceOverview> createState() => _BalanceOverviewState();
}

class _BalanceOverviewState extends State<BalanceOverview> {
  bool _isExpanded = true;
  static const String _prefKey = 'overviewExpanded';

  @override
  void initState() {
    super.initState();
    _loadExpandedState();
  }

  Future<void> _loadExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isExpanded = prefs.getBool(_prefKey) ?? true;
    });
  }

  Future<void> _toggleExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    await prefs.setBool(_prefKey, _isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HomeColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildCurrentBalance(),
          AnimatedCrossFade(
            firstChild: _buildStatsGrid(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Tổng quan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HomeColors.textPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _toggleExpanded,
              icon: AnimatedRotation(
                turns: _isExpanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                  color: HomeColors.primary,
                  size: 24,
                ),
              ),
              tooltip: _isExpanded ? 'Thu gọn' : 'Mở rộng',
            ),
            IconButton(
              onPressed: widget.onVisibilityToggle,
              icon: Icon(
                widget.isBalanceVisible ? HomeIcons.visible : HomeIcons.hidden,
                color: HomeColors.primary,
                size: 24,
              ),
              tooltip: widget.isBalanceVisible ? 'Ẩn số dư' : 'Hiện số dư',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentBalance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HomeColors.balanceBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.balanceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư hiện tại',
            style: TextStyle(
              fontSize: 14,
              color: HomeColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isBalanceVisible
                ? CurrencyFormatter.formatVND(widget.currentUser?.balance ?? 0)
                : '••••••••',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: HomeColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _OverviewStatCard(
                title: 'Thu nhập',
                amount: widget.totalIncome,
                isVisible: widget.isBalanceVisible,
                color: HomeColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewStatCard(
                title: 'Chi tiêu',
                amount: widget.totalExpense,
                isVisible: widget.isBalanceVisible,
                color: HomeColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Bao gồm cả khoản vay trước khi dùng ứng dụng',
                child: _OverviewStatCard(
                  title: 'Cho vay',
                  amount: widget.totalLent,
                  isVisible: widget.isBalanceVisible,
                  color: HomeColors.loanGiven,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: 'Bao gồm cả khoản vay trước khi dùng ứng dụng',
                child: _OverviewStatCard(
                  title: 'Đi vay',
                  amount: widget.totalBorrowed,
                  isVisible: widget.isBalanceVisible,
                  color: HomeColors.loanReceived,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String title;
  final double amount;
  final bool isVisible;
  final Color color;

  const _OverviewStatCard({
    required this.title,
    required this.amount,
    required this.isVisible,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.getStatCardBackground(color),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.getStatCardBorder(color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isVisible ? CurrencyFormatter.formatVND(amount) : '••••••',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
