import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../screens/category/category_card.dart';
import '../../screens/category/category_edit_sheet.dart';

/// Màn hình quản lý danh mục - CRUD Categories
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late TabController _tabController;

  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  bool _isLoading = true;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  // Multi-selection mode
  bool _isSelectionMode = false;
  final Set<int> _selectedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Update UI when tab changes (both tap and swipe)
      if (!_tabController.indexIsChanging) {
        // Tab animation has completed
        setState(() {
          // This will rebuild the tab buttons to reflect current selection
        });
      }

      if (_tabController.indexIsChanging) {
        // Clear search when switching tabs
        _searchController.clear();
        _searchKeyword = '';
        _loadCategories();
      }
    });
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  /// Load all categories from database
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final incomeCategories = await _databaseHelper.getCategoriesByType('income');
      final expenseCategories = await _databaseHelper.getCategoriesByType('expense');

      setState(() {
        _incomeCategories = _filterCategories(incomeCategories);
        _expenseCategories = _filterCategories(expenseCategories);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải danh mục: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filter categories by search keyword
  List<Category> _filterCategories(List<Category> categories) {
    if (_searchKeyword.isEmpty) return categories;

    return categories.where((category) {
      final name = _removeVietnameseDiacritics(category.name.toLowerCase());
      final keyword = _removeVietnameseDiacritics(_searchKeyword.toLowerCase());
      return name.contains(keyword);
    }).toList();
  }

  /// Remove Vietnamese diacritics for search
  String _removeVietnameseDiacritics(String str) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỬÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioooooooooooooooooouuuuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOOOUUUUUUUUUUUUUYYYYYD';

    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  /// Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedCategoryIds.clear();
      }
    });
  }

  /// Toggle category selection
  void _toggleCategorySelection(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  /// Handle long press - activate selection mode and select the item
  void _onCategoryLongPress(int categoryId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedCategoryIds.add(categoryId);
      });
    }
  }

  /// Select all categories in current tab
  void _selectAllInCurrentTab() {
    setState(() {
      final currentCategories = _tabController.index == 0
          ? _expenseCategories
          : _incomeCategories;

      for (var category in currentCategories) {
        if (category.id != null) {
          _selectedCategoryIds.add(category.id!);
        }
      }
    });
  }

  /// Delete selected categories
  Future<void> _deleteSelectedCategories() async {
    if (_selectedCategoryIds.isEmpty) return;

    final count = _selectedCategoryIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa $count danh mục đã chọn?\n\n'
          'Lưu ý: Không thể xóa danh mục đang được sử dụng trong giao dịch hoặc ngân sách.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int successCount = 0;
      int failCount = 0;
      final List<String> failedCategories = [];

      try {
        // Delete all selected categories
        for (var categoryId in _selectedCategoryIds) {
          try {
            await _databaseHelper.deleteCategory(categoryId);
            successCount++;
          } catch (e) {
            failCount++;
            // Lấy tên category để hiển thị trong thông báo lỗi
            final category = [..._incomeCategories, ..._expenseCategories]
                .firstWhere(
                  (cat) => cat.id == categoryId,
                  orElse: () => Category(
                    name: 'Unknown',
                    icon: '',
                    type: 'expense',
                    createdAt: DateTime.now(),
                  ),
                );

            if (e.toString().contains('CATEGORY_IN_USE')) {
              failedCategories.add(category.name);
            }
          }
        }

        setState(() {
          _selectedCategoryIds.clear();
          _isSelectionMode = false;
        });

        _loadCategories();

        if (mounted) {
          if (successCount == 0 && failCount > 0) {
            // All deletions failed
            _showErrorSnackbar(
              'Không thể xóa danh mục vì đang được sử dụng trong giao dịch hoặc ngân sách.\n'
              'Danh mục: ${failedCategories.join(", ")}',
            );
          } else if (successCount > 0 && failCount > 0) {
            // Some succeeded, some failed
            _showWarningSnackbar(
              'Đã xóa $successCount danh mục. $failCount danh mục không thể xóa vì đang được sử dụng.',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Lỗi khi xóa danh mục: $e');
        }
      }
    }
  }

  /// Open add category bottom sheet
  Future<void> _showAddCategorySheet() async {
    final currentType = _tabController.index == 0 ? 'expense' : 'income';

    final result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryEditSheet(
        initialType: currentType,
      ),
    );

    if (result != null) {
      _loadCategories();
    }
  }

  /// Open edit category bottom sheet
  Future<void> _showEditCategorySheet(Category category) async {
    final result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryEditSheet(
        category: category,
        initialType: category.type,
      ),
    );

    if (result != null) {
      _loadCategories();
    }
  }

  /// Delete category with confirmation
  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa danh mục "${category.name}"?\n\nLưu ý: Không thể xóa danh mục đang được sử dụng trong giao dịch hoặc ngân sách.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null) {
      try {
        await _databaseHelper.deleteCategory(category.id!);
        _loadCategories();
      } catch (e) {
        if (mounted) {
          if (e.toString().contains('CATEGORY_IN_USE')) {
            _showErrorSnackbar(
              'Không thể xóa danh mục "${category.name}" vì đang được sử dụng trong giao dịch hoặc ngân sách.',
            );
          } else {
            _showErrorSnackbar('Lỗi khi xóa danh mục: $e');
          }
        }
      }
    }
  }


  /// Show warning message
  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Show error message
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedCategoryIds.length} đã chọn',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Quản lý danh mục',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        backgroundColor: isDark
            ? theme.scaffoldBackgroundColor // Dark: Màu cá voi sát thủ (giống Home_Page)
            : theme.colorScheme.primary, // Light: Xanh biển (giống Home_Page)
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Chọn tất cả',
              onPressed: _selectAllInCurrentTab,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Chọn',
              onPressed: _toggleSelectionMode,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm danh mục...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: _searchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchKeyword = '';
                                });
                                _loadCategories();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchKeyword = value;
                      });
                      _loadCategories();
                    },
                  ),
                ),

                // Custom Tab Selector with color coding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          index: 0,
                          label: 'Chi tiêu',
                          icon: Icons.money_off,
                          color: const Color(0xFFFF6B6B), // Màu đỏ
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTabButton(
                          index: 1,
                          label: 'Thu nhập',
                          icon: Icons.attach_money,
                          color: const Color(0xFF4ECDC4), // Màu xanh
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryGrid(_expenseCategories, 'expense', isDark),
                      _buildCategoryGrid(_incomeCategories, 'income', isDark),
                    ],
                  ),
                ),

                // Bottom action bar when in selection mode
                if (_isSelectionMode && _selectedCategoryIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_selectedCategoryIds.length} danh mục đã chọn',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _deleteSelectedCategories,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Xóa'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddCategorySheet,
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Thêm danh mục'),
            ),
    );
  }

  /// Build category grid
  Widget _buildCategoryGrid(List<Category> categories, String type, bool isDark) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'income' ? Icons.account_balance_wallet : Icons.shopping_bag,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchKeyword.isEmpty
                  ? 'Chưa có danh mục ${type == 'income' ? 'thu nhập' : 'chi tiêu'}'
                  : 'Không tìm thấy danh mục',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showAddCategorySheet,
              icon: const Icon(Icons.add),
              label: const Text('Thêm danh mục mới'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategoryIds.contains(category.id);

        return CategoryCard(
          category: category,
          isSelectionMode: _isSelectionMode,
          isSelected: isSelected,
          onEdit: () => _showEditCategorySheet(category),
          onDelete: () => _deleteCategory(category),
          onSelectionToggle: category.id != null
              ? () => _toggleCategorySelection(category.id!)
              : null,
          onLongPress: category.id != null
              ? () => _onCategoryLongPress(category.id!)
              : null,
        );
      },
    );
  }

  /// Build custom tab button with color coding
  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _tabController.index == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                icon,
                key: ValueKey<bool>(isSelected),
                size: 20,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
