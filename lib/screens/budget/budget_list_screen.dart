import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/budget.dart';
import '../../utils/icon_helper.dart';
import 'add_budget_screen.dart';
import 'budget_category_transaction_screen.dart';

/// Màn hình quản lý ngân sách chi tiết
class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _budgetProgress = [];
  Map<String, dynamic>? _overallBudgetProgress;

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isLoading = true);

    try {
      // Lấy tiến độ ngân sách tổng
      final overallProgress = await _databaseHelper.getOverallBudgetProgress();

      // Lấy tiến độ ngân sách theo danh mục
      final categoryProgress = await _databaseHelper.getBudgetProgress();

      setState(() {
        _overallBudgetProgress = overallProgress;
        _budgetProgress = categoryProgress;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading budget data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBudget(int budgetId) async {
    try {
      await _databaseHelper.deleteBudget(budgetId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa ngân sách'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBudgetData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xóa ngân sách: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editBudget(Map<String, dynamic> item) async {
    // Tạo đối tượng Budget từ dữ liệu item
    final budget = Budget(
      id: item['budgetId'] as int,
      amount: (item['budgetAmount'] as num).toDouble(),
      categoryId: item['categoryId'] as int?,
      startDate: DateTime.parse(item['startDate'] as String),
      endDate: DateTime.parse(item['endDate'] as String),
      createdAt: DateTime.now(), // Sẽ được giữ nguyên khi update
    );

    // Điều hướng đến màn hình sửa
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBudgetScreen(budget: budget),
      ),
    );

    // Reload dữ liệu nếu có thay đổi
    if (result == true) {
      _loadBudgetData();
    }
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 80) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Quản lý ngân sách', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddBudgetScreen(),
                ),
              );
              if (result == true) {
                _loadBudgetData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBudgetData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Ngân sách tổng
                  if (_overallBudgetProgress != null)
                    _buildOverallBudgetCard(_overallBudgetProgress!, currencyFormat, isDark),

                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ngân sách theo danh mục',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_budgetProgress.isEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddBudgetScreen(),
                              ),
                            );
                            if (result == true) {
                              _loadBudgetData();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Danh sách ngân sách theo danh mục
                  if (_budgetProgress.isEmpty)
                    _buildEmptyState()
                  else
                    ..._budgetProgress.map((item) => _buildBudgetCategoryCard(
                          item,
                          currencyFormat,
                          isDark,
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallBudgetCard(
    Map<String, dynamic> data,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final budgetAmount = (data['budgetAmount'] as num).toDouble();
    final totalSpent = (data['totalSpent'] as num).toDouble();
    final progressPercentage = (data['progressPercentage'] as num).toDouble();
    final isOverBudget = data['isOverBudget'] as bool;
    final remainingAmount = budgetAmount - totalSpent;
    final progressColor = _getProgressColor(progressPercentage);

    return Card(
      elevation: isDark ? 4 : 2,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              progressColor.withValues(alpha: 0.1),
              progressColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: progressColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng ngân sách',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        currencyFormat.format(budgetAmount),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isOverBudget)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'VƯỢT MỨC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Menu sửa/xóa cho ngân sách tổng
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Sửa'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editBudget(data);
                    } else if (value == 'delete') {
                      _confirmDelete(data['budgetId'] as int, 'Tổng ngân sách');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin: 0,
                  end: progressPercentage.clamp(0, 100) / 100,
                ),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 16,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  'Đã chi',
                  currencyFormat.format(totalSpent),
                  progressColor,
                ),
                _buildStatItem(
                  context,
                  'Tiến độ',
                  '${progressPercentage.toStringAsFixed(1)}%',
                  progressColor,
                ),
                _buildStatItem(
                  context,
                  isOverBudget ? 'Vượt' : 'Còn lại',
                  currencyFormat.format(remainingAmount.abs()),
                  isOverBudget ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCategoryCard(
    Map<String, dynamic> item,
    NumberFormat currencyFormat,
    bool isDark,
  ) {
    final categoryName = item['categoryName'] as String;
    final categoryIcon = item['categoryIcon'] as String;
    final budgetAmount = (item['budgetAmount'] as num).toDouble();
    final totalSpent = (item['totalSpent'] as num).toDouble();
    final progressPercentage = (item['progressPercentage'] as num).toDouble();
    final remainingAmount = (item['remainingAmount'] as num).toDouble();
    final isOverBudget = item['isOverBudget'] as bool;
    final budgetId = item['budgetId'] as int;

    final progressColor = _getProgressColor(progressPercentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Xem chi tiết lịch sử giao dịch của danh mục này
          _showCategoryTransactions(item);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Icon danh mục
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      IconHelper.getCategoryIcon(categoryIcon),
                      color: progressColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tên và progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                categoryName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Text(
                              '${progressPercentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (progressPercentage / 100).clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currencyFormat.format(totalSpent)} / ${currencyFormat.format(budgetAmount)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              isOverBudget
                                  ? 'Vượt ${currencyFormat.format(remainingAmount.abs())}'
                                  : 'Còn ${currencyFormat.format(remainingAmount)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isOverBudget ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Menu sửa/xóa
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Sửa'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xóa'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editBudget(item);
                      } else if (value == 'delete') {
                        _confirmDelete(budgetId, categoryName);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có ngân sách nào',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm ngân sách để theo dõi chi tiêu của bạn',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int budgetId, String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa ngân sách cho "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBudget(budgetId);
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryTransactions(Map<String, dynamic> item) {
    // Điều hướng đến màn hình chi tiết giao dịch của danh mục
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetCategoryTransactionScreen(
          categoryId: item['categoryId'] as int,
          categoryName: item['categoryName'] as String,
          categoryIcon: item['categoryIcon'] as String,
          startDate: DateTime.parse(item['startDate'] as String),
          endDate: DateTime.parse(item['endDate'] as String),
          budgetAmount: (item['budgetAmount'] as num).toDouble(),
        ),
      ),
    );
  }
}

