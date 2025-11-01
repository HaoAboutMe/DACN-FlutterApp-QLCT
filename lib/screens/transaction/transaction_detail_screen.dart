import 'package:flutter/material.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../home/home_icons.dart';
import '../../database/database_helper.dart';

class TransactionDetailScreen extends StatefulWidget {
  final transaction_model.Transaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Category? _category;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    if (widget.transaction.categoryId != null) {
      try {
        final categories = await _databaseHelper.getAllCategories();
        final category = categories.firstWhere(
          (cat) => cat.id == widget.transaction.categoryId,
          orElse: () => Category(
            id: -1,
            name: '',
            icon: '',
            type: '',
            createdAt: DateTime.now(),
          ),
        );

        if (category.id != -1) {
          setState(() {
            _category = category;
          });
        }
      } catch (e) {
        debugPrint('Error loading category: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Color _getTransactionColor() {
    switch (widget.transaction.type) {
      case 'income':
      case 'debt_collected':
      case 'loan_received':
        return const Color(0xFF4CAF50); // Green for income
      case 'expense':
      case 'debt_paid':
      case 'loan_given':
        return const Color(0xFFF44336); // Red for expense
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon() {
    if (_category != null) {
      return HomeIcons.getIconFromString(_category!.icon);
    } else {
      return HomeIcons.getTransactionTypeIcon(widget.transaction.type);
    }
  }

  String _getTransactionTypeText() {
    switch (widget.transaction.type) {
      case 'income':
        return 'Thu nhập';
      case 'expense':
        return 'Chi tiêu';
      case 'loan_given':
        return 'Cho vay';
      case 'loan_received':
        return 'Đi vay';
      case 'debt_paid':
        return 'Trả nợ';
      case 'debt_collected':
        return 'Thu nợ';
      default:
        return 'Giao dịch';
    }
  }

  String _getAmountDisplay() {
    final isPositive = widget.transaction.type == 'income' ||
                      widget.transaction.type == 'debt_collected' ||
                      widget.transaction.type == 'loan_received';
    final sign = isPositive ? '+' : '-';
    return '$sign${CurrencyFormatter.formatVND(widget.transaction.amount)}';
  }

  String _getLoanCategoryDisplayName() {
    switch (widget.transaction.type) {
      case 'loan_given':
        return 'Cho vay';
      case 'loan_received':
        return 'Đi vay';
      case 'debt_paid':
        return 'Trả nợ';
      case 'debt_collected':
        return 'Thu nợ';
      default:
        return 'Khác';
    }
  }

  Future<void> _deleteTransaction() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa giao dịch "${widget.transaction.description}"?',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336), // Red for delete action
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
        await _databaseHelper.deleteTransaction(widget.transaction.id!);

        // Update user balance after deletion
        await _updateUserBalanceAfterDelete();

        if (mounted) {
          Navigator.pop(context, true); // Return to previous screen with success flag

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Đã xóa giao dịch thành công!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFF4CAF50), // Green for success
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
                'Lỗi khi xóa giao dịch: $e',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFF44336), // Red for error
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Future<void> _updateUserBalanceAfterDelete() async {
    try {
      final currentUserId = await _databaseHelper.getCurrentUserId();
      final currentUser = await _databaseHelper.getUserById(currentUserId);

      if (currentUser == null) return;

      double balanceChange = 0;

      // Calculate balance change based on transaction type
      switch (widget.transaction.type) {
        case 'income':
        case 'debt_collected':
          // Delete income -> subtract from balance
          balanceChange -= widget.transaction.amount;
          break;
        case 'expense':
        case 'debt_paid':
          // Delete expense -> add back to balance
          balanceChange += widget.transaction.amount;
          break;
        case 'loan_given':
          // Delete loan given -> add back to balance
          balanceChange += widget.transaction.amount;
          break;
        case 'loan_received':
          // Delete loan received -> subtract from balance
          balanceChange -= widget.transaction.amount;
          break;
      }

      // Update user balance
      final newBalance = currentUser.balance + balanceChange;
      final updatedUser = currentUser.copyWith(balance: newBalance);
      await _databaseHelper.updateUser(updatedUser);
    } catch (e) {
      debugPrint('Error updating user balance after delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Chi tiết giao dịch',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.onSurface),
              onPressed: widget.onEdit,
              tooltip: 'Chỉnh sửa',
            ),
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.onSurface),
            onPressed: _deleteTransaction,
            tooltip: 'Xóa',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header Card with Icon and Amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _getTransactionColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getTransactionIcon(),
                            color: _getTransactionColor(),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Amount
                        Text(
                          _getAmountDisplay(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getTransactionColor(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Transaction Type
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getTransactionColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getTransactionTypeText(),
                            style: TextStyle(
                              color: _getTransactionColor(),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin chi tiết',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildDetailRow(
                          'Mô tả',
                          widget.transaction.description,
                          Icons.description,
                        ),

                        _buildDetailRow(
                          'Danh mục',
                          _category?.name ?? _getLoanCategoryDisplayName(),
                          Icons.category,
                        ),

                        _buildDetailRow(
                          'Ngày giao dịch',
                          '${widget.transaction.date.day}/${widget.transaction.date.month}/${widget.transaction.date.year}',
                          Icons.calendar_today,
                        ),

                        _buildDetailRow(
                          'Thời gian',
                          '${widget.transaction.date.hour.toString().padLeft(2, '0')}:${widget.transaction.date.minute.toString().padLeft(2, '0')}',
                          Icons.access_time,
                        ),

                        if (widget.transaction.id != null)
                          _buildDetailRow(
                            'ID giao dịch',
                            '#${widget.transaction.id.toString().padLeft(6, '0')}',
                            Icons.tag,
                          ),

                        _buildDetailRow(
                          'Ngày tạo',
                          '${widget.transaction.createdAt.day}/${widget.transaction.createdAt.month}/${widget.transaction.createdAt.year} ${widget.transaction.createdAt.hour.toString().padLeft(2, '0')}:${widget.transaction.createdAt.minute.toString().padLeft(2, '0')}',
                          Icons.add_circle_outline,
                        ),

                        _buildDetailRow(
                          'Cập nhật lần cuối',
                          '${widget.transaction.updatedAt.day}/${widget.transaction.updatedAt.month}/${widget.transaction.updatedAt.year} ${widget.transaction.updatedAt.hour.toString().padLeft(2, '0')}:${widget.transaction.updatedAt.minute.toString().padLeft(2, '0')}',
                          Icons.update,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Edit and Delete Buttons
                  Row(
                    children: [
                      // Edit Button
                      if (widget.onEdit != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'Chỉnh sửa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),

                      if (widget.onEdit != null) const SizedBox(width: 12),

                      // Delete Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteTransaction,
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text(
                            'Xóa',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336), // Red for delete
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
