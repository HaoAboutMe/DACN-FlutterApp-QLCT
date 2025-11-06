import 'package:flutter/material.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../home/home_icons.dart';
import '../../database/database_helper.dart';
import 'edit_transaction_screen.dart';

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
  late transaction_model.Transaction _currentTransaction;
  bool _dataWasModified = false; // Track if data was edited/deleted

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
    _loadTransactionData();
  }

  Future<void> _loadTransactionData() async {
    setState(() {
      _isLoading = true;
    });

    // Reload transaction from database to get latest data
    try {
      final transaction = await _databaseHelper.getTransactionById(_currentTransaction.id!);
      if (transaction != null) {
        _currentTransaction = transaction;
      }
    } catch (e) {
      debugPrint('Error loading transaction: $e');
    }

    await _loadCategory();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCategory() async {
    if (_currentTransaction.categoryId != null) {
      try {
        final categories = await _databaseHelper.getAllCategories();
        final category = categories.firstWhere(
          (cat) => cat.id == _currentTransaction.categoryId,
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
  }

  Color _getTransactionColor() {
    switch (_currentTransaction.type) {
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
      return HomeIcons.getTransactionTypeIcon(_currentTransaction.type);
    }
  }

  String _getTransactionTypeText() {
    switch (_currentTransaction.type) {
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
    final isPositive = _currentTransaction.type == 'income' ||
                      _currentTransaction.type == 'debt_collected' ||
                      _currentTransaction.type == 'loan_received';
    final sign = isPositive ? '+' : '-';
    return '$sign${CurrencyFormatter.formatVND(_currentTransaction.amount)}';
  }

  String _getLoanCategoryDisplayName() {
    switch (_currentTransaction.type) {
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
          'Bạn có chắc chắn muốn xóa giao dịch "${_currentTransaction.description}"?',
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
        await _databaseHelper.deleteTransaction(_currentTransaction.id!);

        // Update user balance after deletion
        await _updateUserBalanceAfterDelete();

        if (mounted) {
          Navigator.pop(context, true); // Return to previous screen with success flag
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
      // ⚠️ QUAN TRỌNG: Không cập nhật số dư cho Transaction liên quan đến Loan
      // Lý do: Số dư sẽ được xử lý khi xóa Loan, tránh cộng 2 lần
      if (_currentTransaction.loanId != null) {
        debugPrint('⚠️ Transaction liên quan đến Loan - KHÔNG cập nhật số dư khi xóa Transaction');
        debugPrint('   Số dư sẽ được xử lý khi xóa Loan để tránh cộng 2 lần');
        return;
      }

      final currentUserId = await _databaseHelper.getCurrentUserId();
      final currentUser = await _databaseHelper.getUserById(currentUserId);

      if (currentUser == null) return;

      double balanceChange = 0;

      // Calculate balance change based on transaction type
      // CHỈ xử lý cho Transaction KHÔNG liên quan đến Loan
      switch (_currentTransaction.type) {
        case 'income':
          // Delete income -> subtract from balance
          balanceChange -= _currentTransaction.amount;
          break;
        case 'expense':
          // Delete expense -> add back to balance
          balanceChange += _currentTransaction.amount;
          break;
        case 'debt_collected':
        case 'debt_paid':
        case 'loan_given':
        case 'loan_received':
          // ⚠️ Các loại này KHÔNG NÊN xảy ra vì đã check loanId ở trên
          // Nhưng để an toàn, log warning
          debugPrint('⚠️ WARNING: Transaction type ${_currentTransaction.type} không nên xảy ra khi loanId = null');
          return;
      }

      // Update user balance
      final newBalance = currentUser.balance + balanceChange;
      final updatedUser = currentUser.copyWith(balance: newBalance);
      await _databaseHelper.updateUser(updatedUser);

      debugPrint('✅ Đã cập nhật số dư: ${currentUser.balance} → $newBalance (${balanceChange > 0 ? '+' : ''}$balanceChange)');
    } catch (e) {
      debugPrint('Error updating user balance after delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Return the modified flag when popping
          Navigator.of(context).pop(_dataWasModified);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.of(context).pop(_dataWasModified);
            },
          ),
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
          // Hiển thị nút edit nếu transaction KHÔNG liên kết với loan
          if (_currentTransaction.loanId == null)
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.onSurface),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditTransactionScreen(transaction: _currentTransaction),
                  ),
                );

                if (result == true && mounted) {
                  // ✅ REALTIME: Reload transaction data to show latest changes
                  await _loadTransactionData();
                  _dataWasModified = true; // Mark that data was modified
                }
              },
              tooltip: 'Chỉnh sửa',
            ),
          if (_currentTransaction.loanId != null)
            Tooltip(
              message: 'Không thể chỉnh sửa giao dịch liên kết với khoản vay',
              child: Icon(Icons.lock, color: colorScheme.onSurfaceVariant),
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
                          _currentTransaction.description,
                          Icons.description,
                        ),

                        _buildDetailRow(
                          'Danh mục',
                          _category?.name ?? _getLoanCategoryDisplayName(),
                          Icons.category,
                        ),

                        _buildDetailRow(
                          'Ngày giao dịch',
                          '${_currentTransaction.date.day}/${_currentTransaction.date.month}/${_currentTransaction.date.year}',
                          Icons.calendar_today,
                        ),

                        _buildDetailRow(
                          'Thời gian',
                          '${_currentTransaction.date.hour.toString().padLeft(2, '0')}:${_currentTransaction.date.minute.toString().padLeft(2, '0')}',
                          Icons.access_time,
                        ),

                        if (_currentTransaction.id != null)
                          _buildDetailRow(
                            'ID giao dịch',
                            '#${_currentTransaction.id.toString().padLeft(6, '0')}',
                            Icons.tag,
                          ),

                        _buildDetailRow(
                          'Ngày tạo',
                          '${_currentTransaction.createdAt.day}/${_currentTransaction.createdAt.month}/${_currentTransaction.createdAt.year} ${_currentTransaction.createdAt.hour.toString().padLeft(2, '0')}:${_currentTransaction.createdAt.minute.toString().padLeft(2, '0')}',
                          Icons.add_circle_outline,
                        ),

                        _buildDetailRow(
                          'Cập nhật lần cuối',
                          '${_currentTransaction.updatedAt.day}/${_currentTransaction.updatedAt.month}/${_currentTransaction.updatedAt.year} ${_currentTransaction.updatedAt.hour.toString().padLeft(2, '0')}:${_currentTransaction.updatedAt.minute.toString().padLeft(2, '0')}',
                          Icons.update,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      ), // Close PopScope
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
