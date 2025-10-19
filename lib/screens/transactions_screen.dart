import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../screens/home/home_colors.dart';
import 'transaction_detail_screen.dart';
import 'edit_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum TimeFilter { week, month, year }

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  List<Transaction> _selectedTransactions = [];
  Map<int, Category> _categoriesMap = {};
  TimeFilter _filter = TimeFilter.week;
  bool _isLoading = true;
  bool _isMultiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _fetchTransactions();
  }

  Future<void> _loadCategories() async {
    final db = DatabaseHelper();
    final categories = await db.getAllCategories();
    setState(() {
      _categoriesMap = {for (var category in categories) category.id!: category};
    });
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper();
    DateTime now = DateTime.now();
    DateTime start;

    switch (_filter) {
      case TimeFilter.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        break;
      case TimeFilter.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case TimeFilter.year:
        start = DateTime(now.year, 1, 1);
        break;
    }

    List<Transaction> all = await db.getAllTransactions();
    _transactions = all.where((t) =>
      (t.type == 'income' || t.type == 'expense' || t.type == 'loan_given' || t.type == 'loan_received') &&
      t.date.isAfter(start.subtract(const Duration(days: 1))) &&
      t.date.isBefore(now.add(const Duration(days: 1)))
    ).toList();

    // Sort by date, newest first
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    setState(() => _isLoading = false);
  }

  double get _totalIncome => _transactions.where((t) => t.type == 'income').fold(0, (sum, t) => sum + t.amount);
  double get _totalExpense => _transactions.where((t) => t.type == 'expense').fold(0, (sum, t) => sum + t.amount);

  void _onFilterChanged(TimeFilter filter) {
    setState(() => _filter = filter);
    _fetchTransactions();
  }

  void _onLongPress(Transaction transaction) {
    setState(() {
      _isMultiSelectMode = true;
      if (!_selectedTransactions.contains(transaction)) {
        _selectedTransactions.add(transaction);
      }
    });
  }

  void _onTransactionTap(Transaction transaction) {
    if (_isMultiSelectMode) {
      setState(() {
        if (_selectedTransactions.contains(transaction)) {
          _selectedTransactions.remove(transaction);
          if (_selectedTransactions.isEmpty) {
            _isMultiSelectMode = false;
          }
        } else {
          _selectedTransactions.add(transaction);
        }
      });
    } else {
      // Navigate to detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(
            transaction: transaction,
            onEdit: () => _editTransaction(transaction),
          ),
        ),
      ).then((_) => _fetchTransactions());
    }
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedTransactions.clear();
    });
  }

  /// Cập nhật số dư user sau khi xóa giao dịch
  Future<void> _updateUserBalanceAfterDelete(List<Transaction> deletedTransactions) async {
    try {
      final db = DatabaseHelper();

      // Lấy thông tin user hiện tại
      final currentUserId = await db.getCurrentUserId();
      final currentUser = await db.getUserById(currentUserId);

      if (currentUser == null) return;

      double balanceChange = 0;

      // Tính toán thay đổi số dư cho từng giao dịch bị xóa
      for (final transaction in deletedTransactions) {
        switch (transaction.type) {
          case 'income':
          case 'debt_collected':
            // Xóa thu nhập -> trừ khỏi số dư
            balanceChange -= transaction.amount;
            debugPrint('Deleted income ${transaction.amount} -> balance change: -${transaction.amount}');
            break;
          case 'expense':
          case 'debt_paid':
            // Xóa chi tiêu -> cộng lại vào số dư (vì khi tạo đã bị trừ)
            balanceChange += transaction.amount;
            debugPrint('Deleted expense ${transaction.amount} -> balance change: +${transaction.amount}');
            break;
          case 'loan_given':
            // Xóa giao dịch cho vay -> cộng lại vào số dư (vì khi tạo đã bị trừ)
            balanceChange += transaction.amount;
            debugPrint('Deleted loan_given ${transaction.amount} -> balance change: +${transaction.amount}');
            break;
          case 'loan_received':
            // Xóa giao dịch đi vay -> trừ khỏi số dư (vì khi tạo đã được cộng)
            balanceChange -= transaction.amount;
            debugPrint('Deleted loan_received ${transaction.amount} -> balance change: -${transaction.amount}');
            break;
          default:
            debugPrint('Unknown transaction type: ${transaction.type} - no balance change');
            break;
        }
      }

      // Cập nhật số dư mới
      final newBalance = currentUser.balance + balanceChange;
      final updatedUser = currentUser.copyWith(balance: newBalance);

      await db.updateUser(updatedUser);

      debugPrint('Updated user balance from ${currentUser.balance} to $newBalance (total change: $balanceChange)');
    } catch (e) {
      debugPrint('Error updating user balance after delete: $e');
    }
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTransactions.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: HomeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa ${_selectedTransactions.length} giao dịch này không?',
          style: TextStyle(
            color: HomeColors.textSecondary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: HomeColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = DatabaseHelper();
        for (var transaction in _selectedTransactions) {
          await db.deleteTransaction(transaction.id!);
        }

        // Cập nhật số dư người dùng sau khi xóa giao dịch
        await _updateUserBalanceAfterDelete(_selectedTransactions);

        setState(() {
          _selectedTransactions.clear();
          _isMultiSelectMode = false;
        });

        await _fetchTransactions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Đã xóa giao dịch thành công!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: HomeColors.income,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lỗi khi xóa: $e',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: HomeColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );

    // Kiểm tra nếu có thay đổi cần refresh
    if (result != null && result['success'] == true) {
      if (result['needRefresh'] == true) {
        // Reload danh sách giao dịch
        await _fetchTransactions();
      }

      if (result['balanceChanged'] == true) {
        // Thông báo cho parent (có thể là Home) rằng cần refresh balance
        // Điều này sẽ được xử lý khi user quay lại Home screen
        debugPrint('Balance changed - Home screen will auto-refresh when resumed');
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}đ';
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      case 'loan_given':
        return Icons.money_off;
      case 'loan_received':
        return Icons.monetization_on;
      default:
        return Icons.help_outline;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'income':
        return HomeColors.income;
      case 'expense':
        return HomeColors.expense;
      case 'loan_given':
        return HomeColors.expense;
      case 'loan_received':
        return HomeColors.income;
      default:
        return Colors.grey;
    }
  }

  String _getTransactionAmountDisplay(Transaction transaction) {
    String sign = transaction.type == 'income' || transaction.type == 'loan_received' ? '+' : '-';
    return '$sign${_formatCurrency(transaction.amount.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        title: Text(
          _isMultiSelectMode
            ? '${_selectedTransactions.length} đã chọn'
            : 'Tất cả giao dịch',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HomeColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _isMultiSelectMode
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _exitMultiSelectMode,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
        actions: [
          if (_isMultiSelectMode && _selectedTransactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedTransactions,
              tooltip: 'Xóa giao dịch đã chọn',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Summary Section
          Container(
            decoration: BoxDecoration(
              color: HomeColors.primary,
              boxShadow: [
                BoxShadow(
                  color: HomeColors.cardShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
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
                children: [
                  // Time Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterButton('Tuần', TimeFilter.week),
                      const SizedBox(width: 8),
                      _buildFilterButton('Tháng', TimeFilter.month),
                      const SizedBox(width: 8),
                      _buildFilterButton('Năm', TimeFilter.year),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Income/Expense Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: HomeColors.balanceBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HomeColors.balanceBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thu nhập',
                                  style: TextStyle(
                                    color: HomeColors.income,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_totalIncome),
                                  style: TextStyle(
                                    color: HomeColors.income,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Chi tiêu',
                                  style: TextStyle(
                                    color: HomeColors.expense,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(_totalExpense),
                                  style: TextStyle(
                                    color: HomeColors.expense,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: HomeColors.primary.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Số dư: ',
                              style: TextStyle(
                                color: HomeColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatCurrency(_totalIncome - _totalExpense),
                              style: TextStyle(
                                color: (_totalIncome - _totalExpense) >= 0
                                  ? HomeColors.income
                                  : HomeColors.expense,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(HomeColors.primary),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đang tải giao dịch...',
                          style: TextStyle(
                            color: HomeColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có giao dịch nào',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'trong khoảng thời gian này',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (ctx, i) {
                          final transaction = _transactions[i];
                          final category = transaction.categoryId != null
                              ? _categoriesMap[transaction.categoryId!]
                              : null;
                          final isSelected = _selectedTransactions.contains(transaction);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                ? HomeColors.primary.withOpacity(0.1)
                                : HomeColors.cardBackground,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _onTransactionTap(transaction),
                                onLongPress: () => _onLongPress(transaction),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                      ? Border.all(color: HomeColors.primary, width: 2)
                                      : null,
                                    boxShadow: !isSelected ? [
                                      BoxShadow(
                                        color: HomeColors.cardShadow,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Selection/Icon
                                      if (_isMultiSelectMode)
                                        Container(
                                          margin: const EdgeInsets.only(right: 12),
                                          child: Icon(
                                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                            color: isSelected ? HomeColors.primary : Colors.grey,
                                            size: 24,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 48,
                                          height: 48,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: HomeColors.getTransactionIconBackground(
                                              _getTransactionColor(transaction.type)
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getTransactionIcon(transaction.type),
                                            color: _getTransactionColor(transaction.type),
                                            size: 24,
                                          ),
                                        ),

                                      // Transaction Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              transaction.description,
                                              style: const TextStyle(
                                                color: HomeColors.textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              category?.name ?? 'Khác',
                                              style: TextStyle(
                                                color: HomeColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                              style: TextStyle(
                                                color: HomeColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Amount and Edit Button
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _getTransactionAmountDisplay(transaction),
                                            style: TextStyle(
                                              color: _getTransactionColor(transaction.type),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (!_isMultiSelectMode) ...[
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: () => _editTransaction(transaction),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: HomeColors.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.edit,
                                                  color: HomeColors.primary,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, TimeFilter filter) {
    final isSelected = _filter == filter;
    return GestureDetector(
      onTap: () => _onFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? HomeColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: HomeColors.primary,
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : HomeColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
