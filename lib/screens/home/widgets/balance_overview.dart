import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../utils/currency_formatter.dart';
import '../../../providers/currency_provider.dart';
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
  // Static cache to preserve state across widget rebuilds
  static bool? _cachedExpandedState;
  static bool _isFirstBuild = true;

  bool _isExpanded = true;
  static const String _prefKey = 'overviewExpanded';

  @override
  void initState() {
    super.initState();
    _loadExpandedState();
  }

  Future<void> _loadExpandedState() async {
    // If we already have cached state, use it immediately
    if (_cachedExpandedState != null) {
      setState(() {
        _isExpanded = _cachedExpandedState!;
      });
      return;
    }

    // First time loading: get from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getBool(_prefKey) ?? true;

    // Cache the state and update UI
    _cachedExpandedState = savedState;

    if (mounted) {
      setState(() {
        _isExpanded = savedState;
      });
    }
  }

  Future<void> _toggleExpanded() async {
    final newState = !_isExpanded;

    setState(() {
      _isExpanded = newState;
    });

    // Update both cache and persistent storage
    _cachedExpandedState = newState;
    _isFirstBuild = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, newState);
  }

  @override
  Widget build(BuildContext context) {
    // Use cached state immediately if available to prevent flicker
    final displayExpanded = _cachedExpandedState ?? _isExpanded;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 8 : 10,
            offset: Offset(0, isDark ? 3 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Consumer<CurrencyProvider>(
            builder: (context, currencyProvider, child) {
              return _buildCurrentBalance(context);
            },
          ),
          // Only show animation after first build
          if (_isFirstBuild && _cachedExpandedState == null)
            displayExpanded ? Consumer<CurrencyProvider>(
              builder: (context, currencyProvider, child) {
                return _buildStatsGrid(context);
              },
            ) : const SizedBox.shrink()
          else
            AnimatedCrossFade(
              firstChild: Consumer<CurrencyProvider>(
                builder: (context, currencyProvider, child) {
                  return _buildStatsGrid(context);
                },
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: displayExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Tổng quan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              tooltip: _isExpanded ? 'Thu gọn' : 'Mở rộng',
            ),
            IconButton(
              onPressed: widget.onVisibilityToggle,
              icon: Icon(
                widget.isBalanceVisible ? HomeIcons.visible : HomeIcons.hidden,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              tooltip: widget.isBalanceVisible ? 'Ẩn số dư' : 'Hiện số dư',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentBalance(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số dư hiện tại',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isBalanceVisible
                ? CurrencyFormatter.formatAmount(widget.currentUser?.balance ?? 0)
                : '••••••••',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
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
            isVisible ? CurrencyFormatter.formatAmount(amount) : '••••••',
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
