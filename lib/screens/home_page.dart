import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/transaction.dart' as transaction_model;
import '../models/category.dart';
import '../utils/currency_formatter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  User? _currentUser;
  List<transaction_model.Transaction> _recentTransactions = [];
  Map<int, Category> _categoriesMap = {};
  bool _isLoading = true;
  bool _isBalanceVisible = true; // Trạng thái ẩn/hiện số dư

  // Các số liệu tổng quan
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalLent = 0;
  double _totalBorrowed = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Lấy user đầu tiên (mặc định)
      final users = await _databaseHelper.getAllUsers();
      if (users.isNotEmpty) {
        _currentUser = users.first;
      }

      // Lấy danh sách giao dịch gần đây
      _recentTransactions = await _databaseHelper.getRecentTransactions(limit: 10);

      // Lấy tất cả categories để map với transaction
      final categories = await _databaseHelper.getAllCategories();
      _categoriesMap = {for (var category in categories) category.id!: category};

      // Tính toán các số liệu tổng quan
      await _calculateOverviewStats();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi load dữ liệu HomePage: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateOverviewStats() async {
    try {
      final allTransactions = await _databaseHelper.getAllTransactions();

      _totalIncome = 0;
      _totalExpense = 0;
      _totalLent = 0;
      _totalBorrowed = 0;

      for (final transaction in allTransactions) {
        switch (transaction.type) {
          case 'income':
          case 'debt_collected':
            _totalIncome += transaction.amount;
            break;
          case 'expense':
            _totalExpense += transaction.amount;
            break;
          case 'loan_given':
            _totalLent += transaction.amount;
            break;
          case 'loan_received':
            _totalBorrowed += transaction.amount;
            break;
        }
      }
    } catch (e) {
      debugPrint('Lỗi tính toán số liệu tổng quan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Nền trắng cho toàn bộ trang
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
              ),
            )
          : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E88E5), // Nền xanh
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 90, // Tăng chiều cao để chứa logo và 2 dòng text
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Logo ứng dụng
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/whales-spent-logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Text chào và subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Xin chào, ${_currentUser?.name ?? 'bạn'}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quản lý chi tiêu Whales Spent',
                      style: TextStyle(
                        fontSize: 17, // Tăng từ 12 lên 14
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Icon thông báo
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    // Badge thông báo
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng thông báo sẽ được phát triển sau')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildOverviewStatsSection(),
            const SizedBox(height: 24),
            _buildQuickActionsSection(),
            const SizedBox(height: 24),
            _buildRecentTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với tên section và icon ẩn/hiện
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng quan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B2A),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
                icon: Icon(
                  _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF1E88E5),
                  size: 24,
                ),
              ),
            ],
          ),

          // Số dư hiện tại
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số dư hiện tại',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF1E88E5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isBalanceVisible
                      ? CurrencyFormatter.formatVND(_currentUser?.balance ?? 0)
                      : '••••••••',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                  ),
                ),
              ],
            ),
          ),

          // 2 hàng × 2 cột
          Row(
            children: [
              Expanded(
                child: _OverviewStatCard(
                  title: 'Thu nhập',
                  amount: _totalIncome,
                  isVisible: _isBalanceVisible,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewStatCard(
                  title: 'Chi tiêu',
                  amount: _totalExpense,
                  isVisible: _isBalanceVisible,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OverviewStatCard(
                  title: 'Cho vay',
                  amount: _totalLent,
                  isVisible: _isBalanceVisible,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewStatCard(
                  title: 'Đi vay',
                  amount: _totalBorrowed,
                  isVisible: _isBalanceVisible,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thao tác nhanh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 16),

          // 4 ô trong 1 hàng
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.trending_up,
                  title: 'Thu nhập',
                  color: Colors.green,
                  onTap: () {
                    _showComingSoonSnackBar('thêm thu nhập');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.trending_down,
                  title: 'Chi tiêu',
                  color: Colors.red,
                  onTap: () {
                    _showComingSoonSnackBar('thêm chi tiêu');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.call_made,
                  title: 'Cho vay',
                  color: Colors.orange,
                  onTap: () {
                    _showComingSoonSnackBar('cho vay');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.call_received,
                  title: 'Đi vay',
                  color: Colors.purple,
                  onTap: () {
                    _showComingSoonSnackBar('đi vay');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giao dịch gần đây',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 16),
          _recentTransactions.isEmpty
              ? _buildEmptyTransactionsWidget()
              : _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final transaction = _recentTransactions[index];
        final category = transaction.categoryId != null
            ? _categoriesMap[transaction.categoryId!]
            : null;

        return _TransactionListItem(
          transaction: transaction,
          category: category,
        );
      },
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tính năng $feature sẽ được phát triển trong bước tiếp theo'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
            isVisible
                ? CurrencyFormatter.formatVND(amount)
                : '••••••',
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80, // Chiều cao cố định thay vì AspectRatio
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22, // Giảm size icon một chút
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12, // Giảm font size để tránh overflow
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final transaction_model.Transaction transaction;
  final Category? category;

  const _TransactionListItem({
    required this.transaction,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon danh mục
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getTransactionColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getTransactionIcon(),
            color: _getTransactionColor(),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),

        // Thông tin giao dịch
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category?.name ?? _getTransactionTypeDisplayName(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1B2A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transaction.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(transaction.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),

        // Số tiền
        Text(
          CurrencyFormatter.formatWithSign(transaction.amount, transaction.type),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _getTransactionColor(),
          ),
        ),
      ],
    );
  }

  IconData _getTransactionIcon() {
    if (category != null) {
      return _getIconFromString(category!.icon);
    }

    switch (transaction.type) {
      case 'income':
        return Icons.trending_up;
      case 'expense':
        return Icons.trending_down;
      case 'loan_given':
        return Icons.call_made;
      case 'loan_received':
        return Icons.call_received;
      case 'debt_paid':
        return Icons.payment;
      case 'debt_collected':
        return Icons.account_balance_wallet;
      default:
        return Icons.swap_horiz;
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'transport':
      case 'directions_car':
        return Icons.directions_car;
      case 'shopping_cart':
      case 'shopping':
        return Icons.shopping_cart;
      case 'home':
        return Icons.home;
      case 'medical_services':
      case 'health':
        return Icons.medical_services;
      case 'school':
      case 'education':
        return Icons.school;
      case 'work':
      case 'business':
        return Icons.work;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.category;
    }
  }

  Color _getTransactionColor() {
    switch (transaction.type) {
      case 'income':
      case 'debt_collected':
      case 'loan_received':
        return Colors.green;
      case 'expense':
      case 'loan_given':
      case 'debt_paid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTransactionTypeDisplayName() {
    switch (transaction.type) {
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
}
