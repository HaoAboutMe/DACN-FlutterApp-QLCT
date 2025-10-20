import 'package:flutter/material.dart';
import '../widgets/whale_navigation_bar.dart';
import 'home/home_page.dart';
import 'transaction/transactions_screen.dart';
import 'loan/loan_list_screen.dart';
import 'statistics/statistics_screen.dart';
import 'profile/profile_screen.dart';

/// MainNavigationWrapper - Wrapper chính quản lý navigation bar động
/// Sử dụng IndexedStack để giữ trạng thái các trang khi chuyển tab
/// Hỗ trợ ẩn/hiện navigation bar khi scroll
class MainNavigationWrapper extends StatefulWidget {
  final int initialIndex;

  const MainNavigationWrapper({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  late int _currentIndex;
  bool _isNavBarVisible = true;
  double _lastScrollOffset = 0;

  // Danh sách các màn hình
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Khởi tạo danh sách màn hình với NotificationListener để detect scroll
    _screens = [
      _buildScreenWithScrollDetection(const HomePage(), 0),
      _buildScreenWithScrollDetection(const TransactionsScreen(), 1),
      _buildScreenWithScrollDetection(const LoanListScreen(), 2),
      _buildScreenWithScrollDetection(const StatisticsScreen(), 3),
      _buildScreenWithScrollDetection(const ProfileScreen(), 4),
    ];
  }

  /// Xây dựng màn hình với scroll detection để ẩn/hiện navigation bar
  Widget _buildScreenWithScrollDetection(Widget screen, int index) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        // Chỉ xử lý khi đang ở tab hiện tại
        if (_currentIndex != index) return false;

        // Chỉ xử lý ScrollUpdateNotification
        if (scrollNotification is ScrollUpdateNotification) {
          final currentOffset = scrollNotification.metrics.pixels;
          final maxScroll = scrollNotification.metrics.maxScrollExtent;

          // Kiểm tra hướng scroll
          if (currentOffset > _lastScrollOffset && currentOffset > 50) {
            // Scroll xuống - Ẩn navigation bar
            if (_isNavBarVisible) {
              setState(() {
                _isNavBarVisible = false;
              });
            }
          } else if (currentOffset < _lastScrollOffset) {
            // Scroll lên - Hiện navigation bar
            if (!_isNavBarVisible) {
              setState(() {
                _isNavBarVisible = true;
              });
            }
          }

          // Luôn hiện navigation bar khi ở đầu trang
          if (currentOffset <= 0) {
            if (!_isNavBarVisible) {
              setState(() {
                _isNavBarVisible = true;
              });
            }
          }

          // Luôn hiện navigation bar khi ở cuối trang
          if (currentOffset >= maxScroll) {
            if (!_isNavBarVisible) {
              setState(() {
                _isNavBarVisible = true;
              });
            }
          }

          _lastScrollOffset = currentOffset;
        }

        return false;
      },
      child: screen,
    );
  }

  /// Xử lý khi tap vào navigation item
  void _onNavItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        // Reset scroll offset khi chuyển tab
        _lastScrollOffset = 0;
        // Luôn hiện navigation bar khi chuyển tab
        _isNavBarVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Nội dung chính - chiếm toàn bộ màn hình
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Navigation bar được đặt phía trên, positioned ở dưới cùng
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WhaleNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onNavItemTapped,
              isVisible: _isNavBarVisible,
            ),
          ),
        ],
      ),
    );
  }
}
