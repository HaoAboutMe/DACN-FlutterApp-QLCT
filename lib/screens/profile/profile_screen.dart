import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../models/user.dart';

/// Màn hình Cá nhân - Lấy cảm hứng từ TPBank Mobile
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  User? _currentUser;
  String _userName = 'Người dùng Whales Spent';
  String _userId = 'WS001234';
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Tải theme mode từ SharedPreferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
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
          _userId = 'WS${user.id?.toString().padLeft(6, '0') ?? '000000'}';
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
        _userId = 'WS000000';
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
        _userId = 'WS${userId.toString().padLeft(6, '0')}';
        _nameController.text = createdUser.name;
      });
    } catch (e) {
      print('Lỗi tạo user mặc định: $e');
    }
  }

  /// Lưu theme mode vào SharedPreferences
  Future<void> _saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    setState(() {
      _isDarkMode = isDark;
    });

    // TODO: Implement theme switching in main app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDark ? 'Đã chuyển sang chế độ tối' : 'Đã chuyển sang chế độ sáng'),
        backgroundColor: const Color(0xFF5D5FEF),
      ),
    );
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
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: _buildHeader(isDark),
            ),

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
      ),
    );
  }

  /// Xây dựng Header với avatar, tên và thông tin người dùng
  Widget _buildHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar với logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF5D5FEF), Color(0xFF00A8CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5D5FEF).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                'assets/images/whales-spent-logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tên người dùng (có thể chỉnh sửa)
          if (_isEditingName)
            Container(
              width: 200,
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _saveUserName(_nameController.text),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _isEditingName = false;
                            _nameController.text = _userName;
                          });
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingName = true;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ID người dùng
          Text(
            'ID: $_userId',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),

          const SizedBox(height: 12),

          // Badge xác thực
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  size: 16,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Đã xác thực',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        'icon': _isDarkMode ? Icons.light_mode : Icons.dark_mode,
        'title': 'Chế độ\n${_isDarkMode ? 'sáng' : 'tối'}',
        'color': const Color(0xFF00A8CC),
        'isToggle': true,
      },
      {
        'icon': Icons.category,
        'title': 'Tùy chỉnh\ndanh mục',
        'color': const Color(0xFFFF6B6B),
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
                _saveThemeMode(!_isDarkMode);
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
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                color: isDark ? Colors.white : Colors.black87,
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
        'icon': Icons.category_outlined,
        'title': 'Quản lý danh mục',
        'subtitle': 'Tùy chỉnh các danh mục thu chi',
      },
      {
        'icon': Icons.schedule_outlined,
        'title': 'Chọn giờ nhắc nhở hằng ngày',
        'subtitle': 'Đặt thời gian nhắc nhở ghi chép chi tiêu',
      },
      {
        'icon': Icons.lock_reset_outlined,
        'title': 'Đặt lại mật khẩu ứng dụng',
        'subtitle': 'Thay đổi mật khẩu bảo vệ ứng dụng',
      },
      {
        'icon': Icons.info_outline,
        'title': 'Thông tin & hỗ trợ',
        'subtitle': 'Phiên bản ứng dụng và liên hệ hỗ trợ',
      },
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cài đặt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
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
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
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
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    setting['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[400],
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
