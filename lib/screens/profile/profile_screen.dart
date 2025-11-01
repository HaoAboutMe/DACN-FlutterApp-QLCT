import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../category/category_management_screen.dart';

/// Màn hình Cá nhân - Lấy cảm hứng từ TPBank Mobile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  String _userName = 'Người dùng Whales Spent';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  /// Tải thông tin người dùng hiện tại từ database
  Future<void> _loadCurrentUser() async {
    try {
      // Lấy danh sách tất cả users (giả sử user đầu tiên là user hiện tại)
      final users = await _databaseHelper.getAllUsers();

      if (users.isNotEmpty) {
        final user = users.first;
        setState(() {
          _currentUser = user;
          _userName = user.name;
          _nameController.text = user.name;
        });
      } else {
        // Nếu chưa có user nào, tạo user mặc định
        await _createDefaultUser();
      }
    } catch (e) {
      print('Lỗi tải thông tin user: $e');
      // Fallback to default values
      setState(() {
        _userName = 'Người dùng Whales Spent';
        _nameController.text = _userName;
      });
    }
  }

  /// Tạo user mặc định nếu chưa có user nào trong database
  Future<void> _createDefaultUser() async {
    try {
      final defaultUser = User(
        name: 'Người dùng Whales Spent',
        balance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userId = await _databaseHelper.insertUser(defaultUser);
      final createdUser = defaultUser.copyWith(id: userId);

      setState(() {
        _currentUser = createdUser;
        _userName = createdUser.name;
        _nameController.text = createdUser.name;
      });
    } catch (e) {
      print('Lỗi tạo user mặc định: $e');
    }
  }

  /// Chuyển đổi theme cho toàn bộ ứng dụng
  Future<void> _toggleTheme(bool isDark) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.toggleTheme(isDark);
  }

  /// Lưu tên người dùng vào database
  Future<void> _saveUserName(String name) async {
    if (_currentUser == null || name.trim().isEmpty) return;

    try {
      // Cập nhật user trong database
      final updatedUser = _currentUser!.copyWith(
        name: name.trim(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUser;
        _userName = name.trim();
        _isEditingName = false;
      });

      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật tên người dùng'),
          backgroundColor: Color(0xFF5D5FEF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Lỗi cập nhật tên user: $e');
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi xảy ra khi cập nhật tên'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Reset về tên cũ
      setState(() {
        _isEditingName = false;
        _nameController.text = _userName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // SliverAppBar với animation
          _buildAnimatedAppBar(isDark),

          // Feature Grid Section
          SliverToBoxAdapter(
            child: _buildFeatureGrid(isDark),
          ),

          // Settings List Section
          SliverToBoxAdapter(
            child: _buildSettingsList(isDark),
          ),

          // Footer
          SliverToBoxAdapter(
            child: _buildFooter(isDark),
          ),
        ],
      ),
    );
  }

  /// Xây dựng SliverAppBar với animation khi cuộn
  Widget _buildAnimatedAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      stretch: true,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Tính toán tỷ lệ co giãn (0.0 = collapsed, 1.0 = expanded)
          final double maxHeight = 300.0;
          final double minHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
          final double currentHeight = constraints.maxHeight;
          final double expandRatio = ((currentHeight - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0);

          return Stack(
            children: [
              FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 18, // Padding dưới rõ ràng, không dính mép
                  top: 0,
                ),
                background: _buildExpandedHeader(isDark, expandRatio),
                title: IgnorePointer(
                  ignoring: expandRatio > 0.2, // Không nhận tap events khi expanded
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: expandRatio < 0.2 ? 1.0 : 0.0,
                    child: _buildCollapsedHeader(isDark),
                  ),
                ),
              ),
              // Nút "Chỉnh sửa thông tin" nằm ngoài FlexibleSpaceBar
              if (expandRatio > 0.99 && !_isEditingName) // Thay đổi từ 0.5 thành 0.3 (biến mất khi kéo 2/3)
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: expandRatio > 0.99 ? 1.0 : ((expandRatio - 0.3) / 0.35).clamp(0.0, 1.0), // Fade từ 0.3 đến 0.65
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isEditingName = true;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: isDark ? Colors.white : const Color(0xFF5D5FEF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Chỉnh sửa thông tin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF5D5FEF),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Header khi AppBar mở rộng (expanded)
  Widget _buildExpandedHeader(bool isDark, double expandRatio) {
    // Tính toán kích thước động dựa trên expandRatio
    final double avatarSize = 70 + (expandRatio * 30); // 70-100 (giảm từ 80-115)
    final double nameFontSize = 15 + (expandRatio * 4); // 15-19 (giảm từ 16-22)

    return Container(
      padding: EdgeInsets.only(
        top: 50 + MediaQuery.of(context).padding.top, // giảm từ 60
        bottom: 20, // giảm từ 30
        left: 20,
        right: 20,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar với logo - kích thước động (nhỏ hơn)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF5D5FEF), Color(0xFF00A8CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D5FEF).withValues(alpha: 0.3 * expandRatio),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(avatarSize / 2),
                child: Image.asset(
                  'assets/images/whales-spent-logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      size: avatarSize * 0.5,
                      color: Colors.white,
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 12 + (expandRatio * 4)), // giảm từ 16 + 8

            // Tên người dùng hoặc TextField chỉnh sửa (cùng vị trí)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _isEditingName
                  ? SizedBox(
                      width: 260, // giảm từ 280
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14, // cố định nhỏ hơn
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.white,
                          isDense: true, // thêm để giảm kích thước
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green, size: 18), // giảm từ 20
                                onPressed: () => _saveUserName(_nameController.text),
                                padding: const EdgeInsets.all(4), // giảm từ 6
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 18), // giảm từ 20
                                onPressed: () {
                                  setState(() {
                                    _isEditingName = false;
                                    _nameController.text = _userName;
                                  });
                                },
                                padding: const EdgeInsets.all(4), // giảm từ 6
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), // giảm từ 12
                            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF5D5FEF), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // giảm từ 16, 12
                        ),
                      ),
                    )
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      child: Text(
                        _userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),

            SizedBox(height: 30 + (expandRatio * 15)), // Tăng padding giữa tên và nút
          ],
        ),
      ),
    );
  }

  /// Header khi AppBar thu gọn (collapsed) - Căn trái theo phong cách TPBank
  Widget _buildCollapsedHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar lớn hơn (52px) - Tương đương TPBank
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF5D5FEF), Color(0xFF00A8CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D5FEF).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/images/whales-spent-logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person,
                  size: 28,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Tên người dùng - Lớn hơn, rõ ràng, căn trái
        Expanded(
          child: Text(
            _userName,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }



  /// Navigate to Category Management Screen
  void _navigateToCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );
  }

  /// Xây dựng Grid các tính năng chính
  Widget _buildFeatureGrid(bool isDark) {
    final features = [
      {
        'icon': Icons.fingerprint,
        'title': 'Xác thực\nvân tay',
        'color': const Color(0xFF5D5FEF),
      },
      {
        'icon': isDark ? Icons.light_mode : Icons.dark_mode,
        'title': 'Chế độ\n${isDark ? 'sáng' : 'tối'}',
        'color': const Color(0xFF00A8CC),
        'isToggle': true,
      },
      {
        'icon': Icons.category,
        'title': 'Tùy chỉnh\ndanh mục',
        'color': const Color(0xFFFF6B6B),
        'isCategoryManagement': true,
      },
      {
        'icon': Icons.notifications,
        'title': 'Thông báo\nnhắc nhở',
        'color': const Color(0xFF4ECDC4),
      },
      {
        'icon': Icons.lock,
        'title': 'Khóa\nứng dụng',
        'color': const Color(0xFFFFE66D),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          return _buildFeatureCard(
            icon: feature['icon'] as IconData,
            title: feature['title'] as String,
            color: feature['color'] as Color,
            isDark: isDark,
            onTap: () {
              if (feature['isToggle'] == true) {
                _toggleTheme(!isDark);
              } else if (feature['isCategoryManagement'] == true) {
                _navigateToCategoryManagement();
              } else {
                _showFeatureSnackbar(feature['title'] as String);
              }
            },
          );
        },
      ),
    );
  }

  /// Xây dựng từng card tính năng
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Xây dựng danh sách cài đặt
  Widget _buildSettingsList(bool isDark) {
    final settings = [
      {
        'icon': Icons.widgets_outlined,
        'title': 'Thêm Widget',
        'subtitle': 'Tùy chỉnh widget trên màn hình chính',
      },
      {
        'icon': Icons.language_outlined,
        'title': 'Tùy chọn ngôn ngữ',
        'subtitle': 'Thay đổi ngôn ngữ hiển thị',
      },
      {
        'icon': Icons.attach_money_outlined,
        'title': 'Tùy chọn loại tiền',
        'subtitle': 'Chọn đơn vị tiền tệ mặc định',
      },
      {
        'icon': Icons.info_outline,
        'title': 'Về chúng tôi',
        'subtitle': 'Thông tin về đội ngũ phát triển',
      },
      {
        'icon': Icons.system_update_outlined,
        'title': 'Phiên bản cập nhật',
        'subtitle': 'Kiểm tra phiên bản mới nhất',
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...settings.asMap().entries.map((entry) {
            final index = entry.key;
            final setting = entry.value;
            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D5FEF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      setting['icon'] as IconData,
                      color: const Color(0xFF5D5FEF),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    setting['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    setting['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  onTap: () => _showFeatureSnackbar(setting['title'] as String),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Xây dựng Footer
  Widget _buildFooter(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Whales Spent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF00A8CC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phiên bản 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '🐋 Quản lý chi tiêu thông minh',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị snackbar cho các tính năng chưa implement
  void _showFeatureSnackbar(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName đang được phát triển...'),
        backgroundColor: const Color(0xFF5D5FEF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}