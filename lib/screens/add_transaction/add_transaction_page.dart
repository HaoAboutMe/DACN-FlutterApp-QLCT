import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../database/repositories/repositories.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/icon_helper.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/category_picker_sheet.dart';

class AddTransactionPage extends StatefulWidget {
  final String? preselectedType;
  final int? preselectedCategoryId;
  final double? initialAmount;
  final String? preselectedDescription;

  const AddTransactionPage({
    super.key,
    this.preselectedType,
    this.preselectedCategoryId,
    this.initialAmount,
    this.preselectedDescription,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final UserRepository _userRepository = UserRepository();
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
    _selectedType = widget.preselectedType ?? 'income';
    _selectedCategoryId = widget.preselectedCategoryId;

    // Nếu có initialAmount từ OCR, tự động điền vào amount controller
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(0);
    }

    // Nếu có preselectedDescription từ shortcut, tự động điền vào description controller
    if (widget.preselectedDescription != null) {
      _descriptionController.text = widget.preselectedDescription!;
    }

    _initializeAnimations();
    _loadCategories();
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
      final categories = await _categoryRepository.getAllCategories();
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
              primary: Theme.of(context).colorScheme.primary,
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
      final inputAmount = CurrencyFormatter.parseAmount(_amountController.text);

      // Convert từ currency hiện tại về VND để lưu vào database
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final amountInVND = currencyProvider.convertToVND(inputAmount);

      // Debug log để kiểm tra parsing và conversion
      debugPrint('=== DEBUG AMOUNT PARSING & CONVERSION ===');
      debugPrint('Input text: "${_amountController.text}"');
      debugPrint('Parsed amount: $inputAmount ${currencyProvider.selectedCurrency}');
      debugPrint('Converted to VND: $amountInVND VND');
      debugPrint('Exchange rate: ${currencyProvider.exchangeRate}');
      debugPrint('========================================');

      if (inputAmount <= 0) {
        _showErrorSnackBar('Số tiền phải lớn hơn 0');
        return;
      }

      final description = _descriptionController.text.trim();

      final transaction = transaction_model.Transaction(
        amount: amountInVND, // Sử dụng amount đã chuyển đổi về VND
        description: description,
        date: _selectedDate,
        categoryId: _selectedCategoryId,
        type: _selectedType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert transaction first
      debugPrint('=== DEBUG TRANSACTION CREATION (UPDATED) ===');
      debugPrint('Transaction amount: ${transaction.amount}');
      debugPrint('Transaction type: ${transaction.type}');

      await _transactionRepository.insertTransaction(transaction);

      // Update user balance dynamically using current user ID
      debugPrint('=== DEBUG BALANCE UPDATE (UPDATED) ===');
      debugPrint('Calling updateUserBalanceAfterTransaction with amount: $amountInVND, type: $_selectedType');

      // Update user balance
      try {
        final currentUserId = await _userRepository.getCurrentUserId();
        final currentUser = await _userRepository.getUserById(currentUserId);

        if (currentUser != null) {
          double balanceChange = 0;
          if (_selectedType == 'income') {
            balanceChange = amountInVND;
          } else if (_selectedType == 'expense') {
            balanceChange = -amountInVND;
          }

          if (balanceChange != 0) {
            final newBalance = currentUser.balance + balanceChange;
            final updatedUser = currentUser.copyWith(balance: newBalance);
            await _userRepository.updateUser(updatedUser);
            debugPrint('Updated balance from ${currentUser.balance} to $newBalance');
          }
        }
      } catch (e) {
        debugPrint('Error updating user balance: $e');
        rethrow;
      }

      // Check if widget is still mounted before using context
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
        return const Color(0xFF4CAF50); // Green for income
      case 'expense':
        return const Color(0xFFF44336); // Red for expense
      default:
        return const Color(0xFF2196F3); // Blue for default
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
    return IconHelper.getCategoryIcon(iconName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true, // Enable automatic screen resize for keyboard
      appBar: AppBar(
        title: const Text(
          'Thêm giao dịch mới',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
            'Loại giao dịch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
            'Số tiền',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              CurrencyInputFormatter(), // Chỉ sử dụng formatter custom
            ],
            decoration: InputDecoration(
              hintText: 'Nhập số tiền (${Provider.of<CurrencyProvider>(context, listen: false).selectedCurrency})',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              suffixText: Provider.of<CurrencyProvider>(context, listen: false).currencySymbol,
              suffixStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.attach_money,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
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

              // Sử dụng CurrencyFormatter.parseAmount để đảm bảo consistency
              final amount = CurrencyFormatter.parseAmount(value);

              debugPrint('=== VALIDATION DEBUG ===');
              debugPrint('Input value: "$value"');
              debugPrint('Parsed amount: $amount');
              debugPrint('Is valid: ${amount > 0}');
              debugPrint('========================');

              if (amount <= 0) {
                return 'Số tiền phải lớn hơn 0';
              }
              return null;
            },
          ),
          // Helper text for currency conversion
          Consumer<CurrencyProvider>(
            builder: (context, currencyProvider, child) {
              if (currencyProvider.selectedCurrency == 'USD') {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Sẽ được chuyển đổi thành VND khi lưu (tỷ giá: 1 USD = ${currencyProvider.exchangeRate.toStringAsFixed(0)} VND)',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
            'Mô tả',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Nhập mô tả cho giao dịch...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.description, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
            'Danh mục',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              hintText: 'Chọn danh mục',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.category, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showAddCategorySheet,
              child: Text(
                'Thêm danh mục mới',
                style: TextStyle(
                  color: colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
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
            'Ngày giao dịch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
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
    // Cho phép empty string
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get current currency from CurrencyFormatter
    final currentCurrency = CurrencyFormatter.getCurrency();

    if (currentCurrency == 'USD') {
      // Cho USD: chỉ cho phép digits và 1 dấu chấm
      String filtered = newValue.text;

      // Loại bỏ tất cả ký tự không hợp lệ
      filtered = filtered.replaceAll(RegExp(r'[^0-9.]'), '');

      // Đảm bảo chỉ có 1 dấu chấm
      final parts = filtered.split('.');
      if (parts.length > 2) {
        filtered = parts[0] + '.' + parts.sublist(1).join('');
      }

      // Giới hạn 3 chữ số thập phân
      if (parts.length == 2 && parts[1].length > 3) {
        filtered = parts[0] + '.' + parts[1].substring(0, 3);
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    } else {
      // Cho VND: chỉ cho phép digits và dấu phẩy
      String filtered = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

      // Auto-format với dấu phẩy ngăn cách hàng nghìn cho VND
      if (filtered.isNotEmpty) {
        final digitsOnly = filtered.replaceAll(',', '');
        if (digitsOnly.isNotEmpty) {
          final amount = double.tryParse(digitsOnly) ?? 0;
          if (amount > 0) {
            final formatter = NumberFormat('#,###', 'vi_VN');
            filtered = formatter.format(amount);
          }
        }
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }
  }
}
