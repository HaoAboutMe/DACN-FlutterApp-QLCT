import 'package:flutter/material.dart';
import '../home_colors.dart';
import '../home_icons.dart';
import '../../../models/quick_action_shortcut.dart';
import '../../../services/quick_action_service.dart';
import '../../../utils/icon_helper.dart';
import '../../add_transaction/add_transaction_page.dart';
import '../../budget/add_budget_screen.dart';
import '../../settings/manage_shortcuts_screen.dart';

class QuickActions extends StatefulWidget {
  final VoidCallback onIncomePressed;
  final VoidCallback onExpensePressed;
  final VoidCallback onLoanGivenPressed;
  final VoidCallback onLoanReceivedPressed;
  final VoidCallback? onTransactionAdded; // Callback to refresh after adding transaction

  const QuickActions({
    super.key,
    required this.onIncomePressed,
    required this.onExpensePressed,
    required this.onLoanGivenPressed,
    required this.onLoanReceivedPressed,
    this.onTransactionAdded,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions> {
  final QuickActionService _shortcutService = QuickActionService();
  List<QuickActionShortcut> _shortcuts = [];
  bool _isLoadingShortcuts = true;

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    try {
      final shortcuts = await _shortcutService.getShortcuts();
      if (mounted) {
        setState(() {
          _shortcuts = shortcuts;
          _isLoadingShortcuts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingShortcuts = false);
      }
    }
  }

  Future<void> _handleShortcutPress(QuickActionShortcut shortcut) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          preselectedType: shortcut.type,
          preselectedCategoryId: shortcut.categoryId,
          preselectedDescription: shortcut.description,
        ),
      ),
    );

    if (result == true && widget.onTransactionAdded != null) {
      widget.onTransactionAdded!();
    }
  }

  Future<void> _handleBudgetPress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddBudgetScreen(),
      ),
    );

    // Optionally refresh if needed
    if (result == true && widget.onTransactionAdded != null) {
      widget.onTransactionAdded!();
    }
  }

  Future<void> _handleAddShortcutPress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageShortcutsScreen(),
      ),
    );

    // Reload shortcuts after returning from manage shortcuts screen
    if (result != null || mounted) {
      await _loadShortcuts();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Thao tác nhanh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Row 1: Original 4 buttons
          Row(
            children: [
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.income,
                  title: 'Thu nhập',
                  color: HomeColors.income,
                  onTap: widget.onIncomePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.expense,
                  title: 'Chi tiêu',
                  color: HomeColors.expense,
                  onTap: widget.onExpensePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.loanGiven,
                  title: 'Cho vay',
                  color: HomeColors.loanGiven,
                  onTap: widget.onLoanGivenPressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionCard(
                  icon: HomeIcons.loanReceived,
                  title: 'Đi vay',
                  color: HomeColors.loanReceived,
                  onTap: widget.onLoanReceivedPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Budget + 3 custom shortcuts
          _isLoadingShortcuts
              ? const SizedBox(
                  height: 70,
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Budget button
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.account_balance_wallet,
                        title: 'Ngân sách',
                        color: Colors.purple,
                        onTap: _handleBudgetPress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Shortcut 1
                    Expanded(
                      child: _shortcuts.isNotEmpty
                          ? QuickActionCard(
                              icon: IconHelper.getCategoryIcon(_shortcuts[0].categoryIcon),
                              title: _shortcuts[0].categoryName,
                              color: _shortcuts[0].type == 'income'
                                  ? HomeColors.income
                                  : HomeColors.expense,
                              onTap: () => _handleShortcutPress(_shortcuts[0]),
                            )
                          : QuickActionCard(
                              icon: Icons.add,
                              title: 'Thêm',
                              color: Colors.grey,
                              onTap: _handleAddShortcutPress,
                              isPlaceholder: true,
                            ),
                    ),
                    const SizedBox(width: 8),
                    // Shortcut 2
                    Expanded(
                      child: _shortcuts.length > 1
                          ? QuickActionCard(
                              icon: IconHelper.getCategoryIcon(_shortcuts[1].categoryIcon),
                              title: _shortcuts[1].categoryName,
                              color: _shortcuts[1].type == 'income'
                                  ? HomeColors.income
                                  : HomeColors.expense,
                              onTap: () => _handleShortcutPress(_shortcuts[1]),
                            )
                          : QuickActionCard(
                              icon: Icons.add,
                              title: 'Thêm',
                              color: Colors.grey,
                              onTap: _handleAddShortcutPress,
                              isPlaceholder: true,
                            ),
                    ),
                    const SizedBox(width: 8),
                    // Shortcut 3
                    Expanded(
                      child: _shortcuts.length > 2
                          ? QuickActionCard(
                              icon: IconHelper.getCategoryIcon(_shortcuts[2].categoryIcon),
                              title: _shortcuts[2].categoryName,
                              color: _shortcuts[2].type == 'income'
                                  ? HomeColors.income
                                  : HomeColors.expense,
                              onTap: () => _handleShortcutPress(_shortcuts[2]),
                            )
                          : QuickActionCard(
                              icon: Icons.add,
                              title: 'Thêm',
                              color: Colors.grey,
                              onTap: _handleAddShortcutPress,
                              isPlaceholder: true,
                            ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isPlaceholder;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        elevation: 2,
        color: isPlaceholder
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPlaceholder
              ? BorderSide(color: Colors.grey.shade300, width: 1, style: BorderStyle.solid)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isPlaceholder ? Colors.grey.shade400 : color,
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final style = TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPlaceholder
                          ? Colors.grey.shade400
                          : Theme.of(context).colorScheme.onSurface,
                    );

                    // Đo width chữ hiện tại
                    final tp = TextPainter(
                      text: TextSpan(text: title, style: style),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout();

                    // Đo width chữ "Ngân sách"
                    final limitTp = TextPainter(
                      text: TextSpan(text: "Ngân sách", style: style),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout();

                    final isTooLong = tp.width > limitTp.width;

                    return Text(
                      title,
                      style: style,
                      maxLines: 1,
                      overflow: isTooLong ? TextOverflow.ellipsis : TextOverflow.visible,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
