import 'package:flutter/material.dart';
import '../../database/repositories/repositories.dart';
import '../../models/category.dart';
import '../../models/icon_group.dart';
import '../../utils/icon_helper.dart';

/// Bottom sheet for adding/editing category
class CategoryEditSheet extends StatefulWidget {
  final Category? category; // null = add mode, not null = edit mode
  final String initialType;

  const CategoryEditSheet({
    super.key,
    this.category,
    required this.initialType,
  });

  @override
  State<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<CategoryEditSheet> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _selectedType;
  IconData? _selectedIcon;
  IconGroup _selectedGroup = IconGroup.all;
  String? _validationError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    if (widget.category != null) {
      // Edit mode - populate existing data
      _nameController.text = widget.category!.name;
      _selectedType = widget.category!.type;
      _selectedIcon = _getCategoryIcon(widget.category!.icon);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Parse icon from string (supports both codePoint and string name)
  IconData _getCategoryIcon(String iconName) {
    return IconHelper.getCategoryIcon(iconName);
  }

  /// Validate input and check duplicates
  Future<bool> _validateInput() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _validationError = 'Vui lòng nhập tên danh mục';
      });
      return false;
    }

    if (_selectedIcon == null) {
      setState(() {
        _validationError = 'Vui lòng chọn biểu tượng';
      });
      return false;
    }

    // Check for duplicates (skip if editing the same category)
    try {
      final iconString = _selectedIcon!.codePoint.toString();
      final exists = await _categoryRepository.existsCategoryByNameIcon(
        name,
        _selectedType,
        iconString,
      );

      if (exists) {
        // If editing, check if it's the same category
        if (widget.category != null) {
          final isSameCategory = widget.category!.name.trim().toLowerCase() == name.toLowerCase() &&
              widget.category!.type == _selectedType &&
              widget.category!.icon == iconString;

          if (!isSameCategory) {
            setState(() {
              _validationError = 'Danh mục đã tồn tại';
            });
            return false;
          }
        } else {
          setState(() {
            _validationError = 'Danh mục đã tồn tại';
          });
          return false;
        }
      }
    } catch (e) {
      setState(() {
        _validationError = 'Lỗi kiểm tra danh mục';
      });
      return false;
    }

    setState(() {
      _validationError = null;
    });
    return true;
  }

  /// Save category (add or update)
  Future<void> _saveCategory() async {
    if (!await _validateInput()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final categoryData = Category(
        id: widget.category?.id,
        name: _nameController.text.trim(),
        icon: _selectedIcon!.codePoint.toString(),
        type: _selectedType,
        budget: widget.category?.budget ?? 0.0,
        createdAt: widget.category?.createdAt ?? DateTime.now(),
      );

      if (widget.category == null) {
        // Add new category
        await _categoryRepository.insertCategory(categoryData);
      } else {
        // Update existing category
        await _categoryRepository.updateCategory(categoryData);
      }

      if (mounted) {
        Navigator.of(context).pop(categoryData);
      }
    } catch (e) {
      if (e.toString().contains('DUPLICATE_CATEGORY')) {
        setState(() {
          _validationError = 'Danh mục đã tồn tại';
        });
      } else {
        setState(() {
          _validationError = 'Lỗi lưu danh mục: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEditMode = widget.category != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditMode ? 'Chỉnh sửa danh mục' : 'Thêm danh mục mới',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Category name input
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Tên danh mục',
                            hintText: 'Ví dụ: Ăn uống, Lương...',
                            prefixIcon: const Icon(Icons.edit),
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorText: _validationError,
                          ),
                          onChanged: (value) {
                            if (_validationError != null) {
                              setState(() {
                                _validationError = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Type selector
                        Text(
                          'Loại danh mục',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                'expense',
                                'Chi tiêu',
                                Icons.money_off,
                                const Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTypeButton(
                                'income',
                                'Thu nhập',
                                Icons.attach_money,
                                const Color(0xFF4ECDC4),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Icon group selector
                        Text(
                          'Nhóm biểu tượng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIconGroupChips(),

                        const SizedBox(height: 20),

                        // Icon selector
                        Text(
                          'Chọn biểu tượng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIconGrid(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Save button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _saveCategory,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditMode ? 'Cập nhật' : 'Thêm danh mục',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build type selector button
  Widget _buildTypeButton(String type, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.surface,
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
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 14,
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

  /// Build icon group chips
  Widget _buildIconGroupChips() {
    final theme = Theme.of(context);

    // Organize icon groups into fixed rows to prevent jumping
    final groups = IconGroup.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Tất cả, Ăn uống, Giải trí, Đi lại
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(groups[0], theme), // Tất cả
            _buildChip(groups[1], theme), // Ăn uống
            _buildChip(groups[2], theme), // Giải trí
            _buildChip(groups[3], theme), // Đi lại
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Mua sắm, Hóa đơn, Giáo dục
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(groups[4], theme), // Mua sắm
            _buildChip(groups[5], theme), // Hóa đơn
            _buildChip(groups[6], theme), // Giáo dục
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: Sức khỏe, Tiết kiệm, Khác
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(groups[7], theme), // Sức khỏe
            _buildChip(groups[8], theme), // Tiết kiệm
            _buildChip(groups[9], theme), // Khác
          ],
        ),
      ],
    );
  }

  /// Build individual chip
  Widget _buildChip(IconGroup group, ThemeData theme) {
    final isSelected = _selectedGroup == group;
    final groupName = IconGroupHelper.getGroupName(group);

    return ChoiceChip(
      label: Text(groupName),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGroup = group;
        });
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      backgroundColor: theme.colorScheme.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  /// Build icon grid
  Widget _buildIconGrid() {
    final theme = Theme.of(context);
    final icons = IconGroupHelper.getIconsByGroup(_selectedGroup);

    if (icons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Không có biểu tượng nào',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final icon = icons[index];
          final isSelected = _selectedIcon?.codePoint == icon.codePoint;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIcon = icon;
                if (_validationError == 'Vui lòng chọn biểu tượng') {
                  _validationError = null;
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}

