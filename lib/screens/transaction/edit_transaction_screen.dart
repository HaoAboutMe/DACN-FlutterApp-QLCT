import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/category_picker_sheet.dart';
import '../home/home_colors.dart';

class EditTransactionScreen extends StatefulWidget {
  final transaction_model.Transaction transaction;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form data
  String _selectedType = 'income';
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  // UI state
  bool _isLoading = false;
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFromTransaction();
    _initializeAnimations();
    _loadCategories();
  }

  void _initializeFromTransaction() {
    // Pre-populate form with existing transaction data
    _amountController.text = CurrencyFormatter.formatForInput(widget.transaction.amount);
    _descriptionController.text = widget.transaction.description;
    _selectedType = widget.transaction.type;
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedDate = widget.transaction.date;
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getAllCategories();
      setState(() {
        _categories = categories;
        _filterCategoriesByType();
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      _showErrorSnackBar('Không thể tải danh mục');
    }
  }

  void _filterCategoriesByType() {
    setState(() {
      _filteredCategories = _categories.where((c) => c.type == _selectedType).toList();

      // Reset selected category if it's not in the filtered list
      if (_selectedCategoryId != null &&
          !_filteredCategories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      _filterCategoriesByType();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: HomeColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Vui lòng chọn danh mục');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sử dụng CurrencyFormatter.parseAmount để parse số tiền an toàn
      final amount = CurrencyFormatter.parseAmount(_amountController.text);

      // Debug log để kiểm tra parsing
      debugPrint('=== DEBUG AMOUNT PARSING (UPDATED) ===');
      debugPrint('Input text: "${_amountController.text}"');
      debugPrint('Parsed amount using CurrencyFormatter: $amount');
      debugPrint('========================');

      if (amount <= 0) {
        _showErrorSnackBar('Số tiền phải lớn hơn 0');
        return;
      }

      final description = _descriptionController.text.trim();

      // Calculate balance difference for update
      final oldAmount = widget.transaction.amount;
      final oldType = widget.transaction.type;

      // Create updated transaction
      final updatedTransaction = widget.transaction.copyWith(
        amount: amount, // Sử dụng amount từ CurrencyFormatter.parseAmount
        description: description,
        date: _selectedDate,
        categoryId: _selectedCategoryId,
        type: _selectedType,
        updatedAt: DateTime.now(),
      );

      // Insert transaction first
      debugPrint('=== DEBUG TRANSACTION CREATION (UPDATED) ===');
      debugPrint('Transaction amount: ${updatedTransaction.amount}');
      debugPrint('Transaction type: ${updatedTransaction.type}');

      await _databaseHelper.updateTransaction(updatedTransaction);

      // Update user balance dynamically using current user ID
      debugPrint('=== DEBUG BALANCE UPDATE (UPDATED) ===');
      debugPrint('Calling updateUserBalanceAfterTransaction with amount: $amount, type: $_selectedType');

      await _updateUserBalanceAfterEdit(
        oldAmount: oldAmount,
        oldType: oldType,
        newAmount: amount,
        newType: _selectedType,
      );

      // Check if widget is still mounted before using context
      if (!mounted) return;

      _showSuccessAnimation();
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      debugPrint('Error saving transaction: $e');
      if (mounted) {
        _showErrorSnackBar('Không thể lưu giao dịch: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserBalanceAfterEdit({
    required double oldAmount,
    required String oldType,
    required double newAmount,
    required String newType,
  }) async {
    // First, reverse the old transaction's effect on balance
    double balanceAdjustment = 0;

    // Reverse old transaction
    if (oldType == 'income') {
      balanceAdjustment -= oldAmount; // Subtract old income
    } else if (oldType == 'expense') {
      balanceAdjustment += oldAmount; // Add back old expense
    }

    // Apply new transaction
    if (newType == 'income') {
      balanceAdjustment += newAmount; // Add new income
    } else if (newType == 'expense') {
      balanceAdjustment -= newAmount; // Subtract new expense
    }

    debugPrint('=== DEBUG BALANCE UPDATE (EDIT) ===');
    debugPrint('Balance adjustment: $balanceAdjustment');

    // Update balance with net change
    if (balanceAdjustment != 0) {
      if (balanceAdjustment > 0) {
        await _databaseHelper.updateUserBalanceAfterTransaction(
          amount: balanceAdjustment,
          transactionType: 'income',
        );
      } else {
        await _databaseHelper.updateUserBalanceAfterTransaction(
          amount: -balanceAdjustment,
          transactionType: 'expense',
        );
      }
    }
  }

  void _showSuccessAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Đã lưu ${_getTransactionTypeText()} thành công!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getTransactionTypeText() {
    switch (_selectedType) {
      case 'income':
        return 'thu nhập';
      case 'expense':
        return 'chi tiêu';
      default:
        return 'giao dịch';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'income':
        return HomeColors.income;
      case 'expense':
        return HomeColors.expense;
      default:
        return HomeColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.trending_up;
      case 'expense':
        return Icons.trending_down;
      default:
        return Icons.payment;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    // Handle empty or null icon names
    if (iconName.isEmpty) {
      return Icons.category;
    }

    // Try to parse as codePoint (for newer categories created via category picker)
    final codePoint = int.tryParse(iconName);
    if (codePoint != null) {
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    }

    // If not a codePoint, map string to Flutter icon (for default categories)
    const categoryIcons = {
      'restaurant': Icons.restaurant,
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'directions_car': Icons.directions_car,
      'shopping_cart': Icons.shopping_cart,
      'shopping_bag': Icons.shopping_bag,
      'shopping': Icons.shopping_cart,
      'home': Icons.home,
      'medical_services': Icons.medical_services,
      'health': Icons.medical_services,
      'school': Icons.school,
      'education': Icons.school,
      'work': Icons.work,
      'business': Icons.work,
      'savings': Icons.savings,
      'entertainment': Icons.movie,
      'movie': Icons.movie,
      'travel': Icons.flight,
      'flight': Icons.flight,
      'utilities': Icons.electrical_services,
      'electrical_services': Icons.electrical_services,
      'attach_money': Icons.attach_money,
      'card_giftcard': Icons.card_giftcard,
      'trending_up': Icons.trending_up,
      'fitness_center': Icons.fitness_center,
      'more_horiz': Icons.more_horiz,
      'other': Icons.category,
      'category': Icons.category,
    };

    return categoryIcons[iconName.toLowerCase()] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      resizeToAvoidBottomInset: true, // Enable automatic screen resize for keyboard
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa giao dịch',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: HomeColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 24),
                  _buildAmountField(),
                  const SizedBox(height: 20),
                  _buildDescriptionField(),
                  const SizedBox(height: 20),
                  _buildCategorySelector(),
                  const SizedBox(height: 20),
                  _buildDateSelector(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                  const SizedBox(height: 20), // Extra space for better scrolling
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
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
          const Text(
            'Loại giao dịch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTypeButton('income', 'Thu nhập', Icons.trending_up)),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeButton('expense', 'Chi tiêu', Icons.trending_down)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final color = _getTypeColor(type);

    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
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
          const Text(
            'Số tiền',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(), // Sử dụng formatter mới
            ],
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'đ',
              prefixIcon: Icon(
                Icons.attach_money,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTypeColor(_selectedType),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập số tiền';
              }
              final amount = double.tryParse(value.replaceAll(',', ''));
              if (amount == null || amount <= 0) {
                return 'Số tiền phải lớn hơn 0';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
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
          const Text(
            'Mô tả',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập mô tả cho giao dịch...',
              prefixIcon: const Icon(Icons.description, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HomeColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập mô tả';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
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
          const Text(
            'Danh mục',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              hintText: 'Chọn danh mục',
              prefixIcon: const Icon(Icons.category, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HomeColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
            ),
            items: _filteredCategories.map((category) {
              return DropdownMenuItem<int>(
                value: category.id,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category.icon),
                      size: 20,
                      color: _getTypeColor(_selectedType),
                    ),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Vui lòng chọn danh mục';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showAddCategorySheet,
              child: const Text(
                'Thêm danh mục mới',
                style: TextStyle(
                  color: HomeColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
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
          const Text(
            'Ngày giao dịch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: HomeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.withValues(alpha: 0.05),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: HomeColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveTransaction,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getTypeColor(_selectedType),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getTypeIcon(_selectedType)),
            const SizedBox(width: 8),
            Text(
              'Lưu ${_getTransactionTypeText()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mở CategoryPickerSheet mới
  Future<void> _showAddCategorySheet() async {
    final selectedCategory = await openCategoryPickerSheet(
      context,
      type: _selectedType,
      selected: _selectedCategoryId != null && _filteredCategories.isNotEmpty
          ? _filteredCategories.cast<Category?>().firstWhere((c) => c?.id == _selectedCategoryId, orElse: () => null)
          : null,
    );

    if (selectedCategory != null) {
      // Tải lại danh sách categories để có category mới
      await _loadCategories();

      // Cập nhật category được chọn
      if (mounted) {
        setState(() {
          _selectedCategoryId = selectedCategory.id;
        });

        // Hiển thị thông báo thành công nếu là category mới
        if (selectedCategory.id != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Đã chọn danh mục "${selectedCategory.name}"'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse số tiền bằng CurrencyFormatter để đảm bảo consistency
    final amount = CurrencyFormatter.parseAmount(newValue.text);

    if (amount == 0) {
      return newValue.copyWith(text: '');
    }

    // Format lại bằng CurrencyFormatter
    final formatted = CurrencyFormatter.formatForInput(amount);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
