import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/budget.dart';
import '../../utils/icon_helper.dart';
import '../../utils/currency_formatter.dart';
import '../transaction/transaction_detail_screen.dart';
import 'add_budget_screen.dart';

/// Màn hình hiển thị toàn bộ giao dịch trong khoảng thời gian ngân sách tổng
class OverallBudgetTransactionScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final double budgetAmount;
  final int? budgetId; // ID của ngân sách để có thể edit/delete

  const OverallBudgetTransactionScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.budgetAmount,
    this.budgetId,
  });

  @override
  State<OverallBudgetTransactionScreen> createState() => _OverallBudgetTransactionScreenState();
}

class _OverallBudgetTransactionScreenState extends State<OverallBudgetTransactionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = true;
  List<transaction_model.Transaction> _transactions = [];
  double _totalSpent = 0;
  Map<int, String> _categoryNames = {};
  Map<int, String> _categoryIcons = {};

  // Track current budget amount (can be updated after edit)
  late double _currentBudgetAmount;
  late DateTime _currentStartDate;
  late DateTime _currentEndDate;

  @override
  void initState() {
    super.initState();
    // Initialize with widget values
    _currentBudgetAmount = widget.budgetAmount;
    _currentStartDate = widget.startDate;
    _currentEndDate = widget.endDate;
    _loadData();
  }

  Future<void> _editBudget() async {
    if (widget.budgetId == null) return;

    // Tạo đối tượng Budget để chỉnh sửa
    final budget = Budget(
      id: widget.budgetId,
      amount: _currentBudgetAmount,
      categoryId: null, // Overall budget không có categoryId
      startDate: _currentStartDate,
      endDate: _currentEndDate,
      createdAt: DateTime.now(),
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBudgetScreen(budget: budget),
      ),
    );

    if (result == true) {
      // Reload budget info from database
      if (widget.budgetId != null) {
        final updatedBudget = await _databaseHelper.getBudgetById(widget.budgetId!);
        if (updatedBudget != null) {
          // Check if budget was changed to category budget (no longer overall)
          if (updatedBudget.categoryId != null) {
            // Changed to category budget - go back to BudgetListScreen
            if (mounted) {
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(
              //     content: Text('Đã cập nhật ngân sách'),
              //     backgroundColor: Colors.green,
              //     duration: Duration(seconds: 2),
              //   ),
              // );
              Navigator.pop(context, true); // Return to BudgetListScreen
            }
            return;
          }

          // Still overall budget - update and reload
          setState(() {
            _currentBudgetAmount = updatedBudget.amount;
            _currentStartDate = updatedBudget.startDate;
            _currentEndDate = updatedBudget.endDate;
          });
        }
      }

      // Reload data to show updated budget info
      await _loadData();

      // Show success message
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Đã cập nhật ngân sách'),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    }
  }

  Future<void> _deleteBudget() async {
    if (widget.budgetId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ngân sách tổng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteBudget(widget.budgetId!);
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('Đã xóa ngân sách'),
          //     backgroundColor: Colors.green,
          //   ),
          // );
          // Go back to BudgetListScreen
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa ngân sách: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load all categories for name/icon mapping
      final categories = await _databaseHelper.getAllCategories();
      final categoryNameMap = <int, String>{};
      final categoryIconMap = <int, String>{};

      for (var category in categories) {
        if (category.id != null) {
          categoryNameMap[category.id!] = category.name;
          categoryIconMap[category.id!] = category.icon;
        }
      }

      // Lấy tất cả giao dịch trong khoảng thời gian (use current dates)
      final allTransactions = await _databaseHelper.getTransactionsByDateRange(
        _currentStartDate,
        _currentEndDate,
      );

      // Lọc chỉ lấy giao dịch chi tiêu và các giao dịch từ Loan (cho vay, trả nợ)
      final expenseTransactions = allTransactions.where((transaction) {
        return transaction.type == 'expense' ||
               transaction.type == 'loan_given' ||
               transaction.type == 'debt_paid';
      }).toList();

      // Sắp xếp theo ngày giảm dần (mới nhất trên cùng)
      expenseTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Tính tổng chi tiêu
      double total = 0;
      for (var transaction in expenseTransactions) {
        total += transaction.amount;
      }

      setState(() {
        _transactions = expenseTransactions;
        _totalSpent = total;
        _categoryNames = categoryNameMap;
        _categoryIcons = categoryIconMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use CurrencyFormatter for multi-currency support
    final dateFormat = DateFormat('dd/MM/yyyy');
    final progressPercentage = _currentBudgetAmount > 0
        ? (_totalSpent / _currentBudgetAmount) * 100
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          // Return true when user presses back button to trigger refresh on previous screen
          Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark
              ? Theme.of(context).scaffoldBackgroundColor
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tổng ngân sách',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          actions: widget.budgetId != null ? [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editBudget,
              tooltip: 'Sửa ngân sách',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteBudget,
              tooltip: 'Xóa ngân sách',
            ),
          ] : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header thống kê
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kỳ ngân sách',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFormat.format(_currentStartDate)} - ${dateFormat.format(_currentEndDate)}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đã chi',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatAmount(_totalSpent),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _totalSpent > _currentBudgetAmount
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Hạn mức',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.formatAmount(_currentBudgetAmount),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (progressPercentage / 100).clamp(0, 1),
                            minHeight: 10,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressPercentage >= 100
                                  ? Colors.red
                                  : progressPercentage >= 80
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${progressPercentage.toStringAsFixed(1)}% đã sử dụng',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Danh sách giao dịch
                  Expanded(
                    child: _transactions.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _transactions[index];
                              return _buildTransactionItem(transaction, dateFormat);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTransactionItem(
    transaction_model.Transaction transaction,
    DateFormat dateFormat,
  ) {
    // Get category name and icon - handle loan transactions specially
    String categoryName;
    String categoryIcon;

    switch (transaction.type) {
      case 'loan_given':
        categoryName = 'Cho vay';
        categoryIcon = 'call_made';
        break;
      case 'loan_received':
        categoryName = 'Đi vay';
        categoryIcon = 'call_received';
        break;
      case 'debt_paid':
        categoryName = 'Trả nợ';
        categoryIcon = 'payment';
        break;
      case 'debt_collected':
        categoryName = 'Thu nợ';
        categoryIcon = 'account_balance_wallet';
        break;
      default:
        // For regular income/expense transactions, get from category mapping
        categoryName = _categoryNames[transaction.categoryId] ?? 'Khác';
        categoryIcon = _categoryIcons[transaction.categoryId] ?? 'more_horiz';
    }

    // Use primary color for icon (red for expense category)
    final iconColor = Colors.red;
    final iconBackgroundColor = iconColor.withValues(alpha: 0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            IconHelper.getCategoryIcon(categoryIcon),
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              dateFormat.format(transaction.date),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
        trailing: Text(
          '-${CurrencyFormatter.formatAmount(transaction.amount)}',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                transaction: transaction,
              ),
            ),
          ).then((result) {
            // Reload transactions if any changes were made
            if (result == true) {
              _loadData();
            }
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn chưa có giao dịch nào\ntrong khoảng thời gian này',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

