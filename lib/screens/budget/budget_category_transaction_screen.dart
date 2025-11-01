import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;

/// Màn hình hiển thị chi tiết giao dịch theo danh mục trong khoảng thời gian ngân sách
class BudgetCategoryTransactionScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final DateTime startDate;
  final DateTime endDate;
  final double budgetAmount;

  const BudgetCategoryTransactionScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.startDate,
    required this.endDate,
    required this.budgetAmount,
  });

  @override
  State<BudgetCategoryTransactionScreen> createState() => _BudgetCategoryTransactionScreenState();
}

class _BudgetCategoryTransactionScreenState extends State<BudgetCategoryTransactionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = true;
  List<transaction_model.Transaction> _transactions = [];
  double _totalSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      // Lấy tất cả giao dịch trong khoảng thời gian
      final allTransactions = await _databaseHelper.getTransactionsByDateRange(
        widget.startDate,
        widget.endDate,
      );

      // Lọc chỉ lấy giao dịch chi tiêu của danh mục này
      final categoryTransactions = allTransactions.where((transaction) {
        return transaction.categoryId == widget.categoryId &&
               transaction.type == 'expense';
      }).toList();

      // Tính tổng chi tiêu
      double total = 0;
      for (var transaction in categoryTransactions) {
        total += transaction.amount;
      }

      setState(() {
        _transactions = categoryTransactions;
        _totalSpent = total;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final progressPercentage = widget.budgetAmount > 0
        ? (_totalSpent / widget.budgetAmount) * 100
        : 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            Builder(
              builder: (context) {
                final iconCode = int.tryParse(widget.categoryIcon);
                return iconCode != null
                    ? Icon(
                        IconData(iconCode, fontFamily: 'MaterialIcons'),
                        size: 24,
                      )
                    : Text(
                        widget.categoryIcon,
                        style: const TextStyle(fontSize: 24),
                      );
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.categoryName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                        '${dateFormat.format(widget.startDate)} - ${dateFormat.format(widget.endDate)}',
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
                                currencyFormat.format(_totalSpent),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _totalSpent > widget.budgetAmount
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
                                currencyFormat.format(widget.budgetAmount),
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
                            return _buildTransactionItem(transaction, currencyFormat, dateFormat);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionItem(
    transaction_model.Transaction transaction,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_upward,
            color: Colors.red,
            size: 24,
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          dateFormat.format(transaction.date),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        trailing: Text(
          '-${currencyFormat.format(transaction.amount)}',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
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

