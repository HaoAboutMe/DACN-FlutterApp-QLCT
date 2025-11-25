import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../database/repositories/repositories.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../utils/currency_formatter.dart';
import '../../providers/currency_provider.dart';
import 'package:provider/provider.dart';

/// Màn hình thêm ngân sách mới
class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;

  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final BudgetRepository _budgetRepository = BudgetRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  bool _isOverallBudget = true; // Mặc định là ngân sách tổng
  Category? _selectedCategory;
  List<Category> _expenseCategories = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  ); // Cuối tháng

  @override
  void initState() {
    super.initState();
    _initializeData();
    if (widget.budget != null) {
      _initializeEditMode();
    }
  }

  /// Initialize data - categories will be auto-initialized by DatabaseHelper in main.dart
  Future<void> _initializeData() async {
    try {
      // Simply load categories - default ones should already exist from main.dart
      await _loadCategories();
    } catch (e) {
      debugPrint('Error initializing data: $e');
      await _loadCategories();
    }
  }

  Future<void> _initializeEditMode() async {
    final budget = widget.budget!;

    // Convert VND amount từ database sang currency hiện tại để hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final displayAmount = currencyProvider.convertFromVND(budget.amount);
      _amountController.text = CurrencyFormatter.formatForInput(displayAmount);
    });

    _startDate = budget.startDate;
    _endDate = budget.endDate;
    _isOverallBudget = budget.categoryId == null;

    // Nếu là ngân sách theo danh mục, tìm và gán category đã chọn
    if (!_isOverallBudget && budget.categoryId != null) {
      // Đợi categories load xong
      await _loadCategories();

      // Tìm category tương ứng
      try {
        final category = _expenseCategories.firstWhere(
          (cat) => cat.id == budget.categoryId,
        );

        setState(() {
          _selectedCategory = category;
        });
      } catch (e) {
        debugPrint('Category not found: ${budget.categoryId}');
      }
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryRepository.getCategoriesByType('expense');
      setState(() {
        _expenseCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF5D5FEF),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isOverallBudget && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn danh mục'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse input amount using CurrencyFormatter for consistency
      final inputAmount = CurrencyFormatter.parseAmount(_amountController.text);

      // Convert từ currency hiện tại về VND để lưu vào database
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final amountInVND = currencyProvider.convertToVND(inputAmount);

      // Debug log để kiểm tra conversion
      debugPrint('=== DEBUG BUDGET AMOUNT CONVERSION ===');
      debugPrint('Input text: "${_amountController.text}"');
      debugPrint('Parsed amount: $inputAmount ${currencyProvider.selectedCurrency}');
      debugPrint('Converted to VND: $amountInVND VND');
      debugPrint('Exchange rate: ${currencyProvider.exchangeRate}');
      debugPrint('======================================');

      // Đảm bảo endDate là cuối ngày (23:59:59) để budget tồn tại cả ngày
      final endDateEndOfDay = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      final budget = Budget(
        id: widget.budget?.id,
        amount: amountInVND,
        categoryId: _isOverallBudget ? null : _selectedCategory?.id,
        startDate: _startDate,
        endDate: endDateEndOfDay,
        createdAt: widget.budget?.createdAt ?? DateTime.now(),
      );

      if (widget.budget == null) {
        await _budgetRepository.insertBudget(budget);
      } else {
        await _budgetRepository.updateBudget(budget);
      }

      if (!mounted) return;


      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving budget: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu ngân sách: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use CurrencyFormatter for multi-currency support
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.budget == null ? 'Thêm ngân sách' : 'Sửa ngân sách', style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Loại ngân sách
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loại ngân sách',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          RadioListTile<bool>(
                            title: const Text('Ngân sách tổng'),
                            subtitle: const Text('Áp dụng cho tất cả chi tiêu'),
                            value: true,
                            groupValue: _isOverallBudget,
                            onChanged: (value) {
                              setState(() {
                                _isOverallBudget = value!;
                                _selectedCategory = null;
                              });
                            },
                          ),
                          RadioListTile<bool>(
                            title: const Text('Ngân sách theo danh mục'),
                            subtitle: const Text('Áp dụng cho danh mục cụ thể'),
                            value: false,
                            groupValue: _isOverallBudget,
                            onChanged: (value) {
                              setState(() => _isOverallBudget = value!);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Chọn danh mục (nếu không phải ngân sách tổng)
                  if (!_isOverallBudget)
                    Card(
                      child: InkWell(
                        onTap: () => _showCategoryPicker(),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.category,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Danh mục',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedCategory?.name ?? 'Chọn danh mục',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedCategory != null)
                                _buildCategoryIcon(_selectedCategory!),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (!_isOverallBudget) const SizedBox(height: 16),

                  // Số tiền ngân sách
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số tiền ngân sách',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                              prefixIcon: const Icon(Icons.attach_money),
                              suffixText: Provider.of<CurrencyProvider>(context, listen: false).currencySymbol,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập số tiền';
                              }
                              // Use CurrencyFormatter for consistent parsing
                              final amount = CurrencyFormatter.parseAmount(value);
                              if (amount <= 0) {
                                return 'Số tiền phải lớn hơn 0';
                              }
                              return null;
                            },

                          ),
                          // Helper text for currency conversion
                          const SizedBox(height: 8),
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, child) {
                              if (currencyProvider.selectedCurrency == 'USD') {
                                return Text(
                                  'Sẽ được chuyển đổi thành VND khi lưu (tỷ giá: 1 USD = ${currencyProvider.exchangeRate.toStringAsFixed(0)} VND)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Khoảng thời gian
                  Card(
                    child: InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khoảng thời gian',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Từ ${dateFormat.format(_startDate)} đến ${dateFormat.format(_endDate)}',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_endDate.difference(_startDate).inDays + 1} ngày',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nút lưu
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveBudget,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D5FEF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.budget == null ? 'Thêm ngân sách' : 'Cập nhật',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn danh mục',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _expenseCategories.length,
                itemBuilder: (context, index) {
                  final category = _expenseCategories[index];
                  // Parse icon từ String sang IconData
                  final iconCode = int.tryParse(category.icon);

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildCategoryIcon(category),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    trailing: _selectedCategory?.id == category.id
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                  );

                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(Category category) {
    try {
      // Nếu icon là dạng số (codePoint)
      final int? code = int.tryParse(category.icon);
      if (code != null) {
        return Icon(
          IconData(code, fontFamily: 'MaterialIcons'),
          color: Colors.red,
          size: 24,
        );
      }

      // Nếu icon là dạng text như "movie" hoặc "more_horiz"
      // => ánh xạ tạm sang MaterialIcons theo tên
      final Map<String, IconData> fallbackIcons = {
        'movie': Icons.movie,
        'more_horiz': Icons.more_horiz,
        'shopping_bag': Icons.shopping_bag,
        'medical_services': Icons.medical_services,
        'restaurant': Icons.restaurant,
        'directions_car': Icons.directions_car,
      };

      if (fallbackIcons.containsKey(category.icon)) {
        return Icon(
          fallbackIcons[category.icon]!,
          color: Colors.red,
          size: 24,
        );
      }

      return const Icon(Icons.category, color: Colors.red, size: 24);
    } catch (e) {
      // Nếu parse thất bại hoàn toàn
      return const Icon(Icons.category, color: Colors.grey, size: 24);
    }
  }
}

// CurrencyInputFormatter class for proper currency input formatting
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
