import 'package:flutter/material.dart';
import '../widgets/whale_navigation_bar.dart';
import 'home/home_page.dart';
import 'transaction/transactions_screen.dart';
import 'loan/loan_list_screen.dart';
import 'statistics/statistics_screen.dart';
import 'profile/profile_screen.dart';

/// GlobalKey để truy cập MainNavigationWrapper từ bất kỳ đâu
final GlobalKey<_MainNavigationWrapperState> mainNavigationKey = GlobalKey<_MainNavigationWrapperState>();

/// Ghi nhớ tab cần mở nếu widget Android kích hoạt khi app chưa sẵn sàng
final ValueNotifier<int?> pendingWidgetTabNotifier = ValueNotifier<int?>(null);

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
  late final VoidCallback _pendingTabListener;

  // Keys for accessing screen states for reload functionality
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _transactionsKey = GlobalKey();
  final GlobalKey _loanKey = GlobalKey();
  final GlobalKey _statisticsKey = GlobalKey();

  // Danh sách các màn hình
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pendingTabListener = _consumePendingWidgetTab;
    pendingWidgetTabNotifier.addListener(_pendingTabListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingWidgetTab());

    // Khởi tạo danh sách màn hình với NotificationListener để detect scroll
    _screens = [
      _buildScreenWithScrollDetection(HomePage(key: _homeKey), 0),
      _buildScreenWithScrollDetection(TransactionsScreen(key: _transactionsKey), 1),
      _buildScreenWithScrollDetection(LoanListScreen(key: _loanKey), 2),
      _buildScreenWithScrollDetection(StatisticsScreen(key: _statisticsKey), 3),
      _buildScreenWithScrollDetection(const ProfileScreen(), 4),
    ];
  }

  @override
  void dispose() {
    pendingWidgetTabNotifier.removeListener(_pendingTabListener);
    super.dispose();
  }

  void _consumePendingWidgetTab() {
    final pendingTab = pendingWidgetTabNotifier.value;
    if (pendingTab == null || !mounted) return;

    if (pendingTab != _currentIndex) {
      switchToTab(pendingTab);
    } else {
      _triggerTabReload(pendingTab);
    }

    pendingWidgetTabNotifier.value = null;
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

          // Luôn hiện navigation bar khi ở đầu trang (scroll position = 0)
          if (currentOffset <= 0) {
            if (!_isNavBarVisible) {
              setState(() {
                _isNavBarVisible = true;
              });
            }
          }

          // Loại bỏ logic tự động hiện khi ở cuối trang
          // Người dùng phải vuốt lên để hiện lại navigation bar

          _lastScrollOffset = currentOffset;
        }

        return false;
      },
      child: screen,
    );
  }

  /// Public method để chuyển tab từ bên ngoài
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length && index != _currentIndex) {
      setState(() {
        _currentIndex = index;
        _lastScrollOffset = 0;
        _isNavBarVisible = true;
      });

      // Trigger reload when switching to specific tabs
      _triggerTabReload(index);
    }
  }

  /// Xử lý khi tap vào navigation item
  void _onNavItemTapped(int index) {
    debugPrint('🔄 Navigation tapped: tab $index (current: $_currentIndex)');

    setState(() {
      // Reset scroll offset khi chuyển tab
      _lastScrollOffset = 0;
      // Luôn hiện navigation bar khi chuyển tab
      _isNavBarVisible = true;
    });

    // ALWAYS trigger reload - even for the same tab (REALTIME requirement)
    _triggerRealtimeReload(index);

    // Update current index after triggering reload
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  /// ✅ REALTIME RELOAD - Gọi public methods thay vì private methods
  void _triggerRealtimeReload(int tabIndex) {
    debugPrint('🚀 REALTIME RELOAD for tab $tabIndex');

    // Thêm delay nhỏ để đảm bảo UI đã render xong
    Future.delayed(const Duration(milliseconds: 50), () {
      switch (tabIndex) {
        case 0: // HomePage
          debugPrint('🏠 HomePage: Calling refreshData()...');
          final homeState = _homeKey.currentState;
          if (homeState != null && homeState is State && homeState.mounted) {
            try {
              // Gọi public method refreshData() thay vì private _refreshHomeData()
              (homeState as dynamic).refreshData?.call();
              debugPrint('✅ HomePage: refreshData() called successfully');
            } catch (e) {
              debugPrint('⚠️ HomePage: Fallback to setState - $e');
              homeState.setState(() {});
            }
          }
          break;

        case 1: // TransactionsScreen
          debugPrint('💳 TransactionsScreen: Calling loadData()...');
          final transactionsState = _transactionsKey.currentState;
          if (transactionsState != null && transactionsState is State && transactionsState.mounted) {
            try {
              // Gọi public method loadData() thay vì private _loadData()
              (transactionsState as dynamic).loadData?.call();
              debugPrint('✅ TransactionsScreen: loadData() called successfully');
            } catch (e) {
              debugPrint('⚠️ TransactionsScreen: Fallback to setState - $e');
              transactionsState.setState(() {});
            }
          }
          break;

        case 2: // LoanListScreen
          debugPrint('💰 LoanListScreen: Calling loadLoans()...');
          final loanState = _loanKey.currentState;
          if (loanState != null && loanState is State && loanState.mounted) {
            try {
              // Gọi public method loadLoans() thay vì private _loadLoans()
              (loanState as dynamic).loadLoans?.call();
              debugPrint('✅ LoanListScreen: loadLoans() called successfully');
            } catch (e) {
              debugPrint('⚠️ LoanListScreen: Fallback to setState - $e');
              loanState.setState(() {});
            }
          }
          break;

        case 3: // StatisticsScreen
          debugPrint('📊 StatisticsScreen: Calling refreshData()...');
          final statisticsState = _statisticsKey.currentState;
          if (statisticsState != null && statisticsState is State && statisticsState.mounted) {
            try {
              // Gọi public method refreshData()
              (statisticsState as dynamic).refreshData?.call();
              debugPrint('✅ StatisticsScreen: refreshData() called successfully');
            } catch (e) {
              debugPrint('⚠️ StatisticsScreen: Fallback to setState - $e');
              statisticsState.setState(() {});
            }
          }
          break;

        default:
          debugPrint('📊 Other tabs: No realtime reload needed');
          break;
      }
    });
  }

  /// Trigger reload for specific tabs when switched to
  void _triggerTabReload(int tabIndex) {
    // Add a small delay to ensure the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 MainNavigationWrapper: Triggering reload for tab $tabIndex');

      switch (tabIndex) {
        case 0: // HomePage
          final homeState = _homeKey.currentState;
          if (homeState != null && homeState is State) {
            debugPrint('🏠 HomePage: Triggering refresh...');
            try {
              (homeState as dynamic)._refreshHomeData?.call();
              debugPrint('✅ HomePage: Refresh method called successfully');
            } catch (e) {
              debugPrint('⚠️ HomePage: Refresh method not found, using setState fallback');
              if (homeState.mounted) {
                homeState.setState(() {});
              }
            }
          } else {
            debugPrint('❌ HomePage: State not found or invalid');
          }
          break;

        case 1: // TransactionsScreen
          final transactionsState = _transactionsKey.currentState;
          if (transactionsState != null && transactionsState is State) {
            debugPrint('💳 TransactionsScreen: Triggering reload...');
            try {
              (transactionsState as dynamic)._loadData?.call();
              debugPrint('✅ TransactionsScreen: Reload method called successfully');
            } catch (e) {
              debugPrint('⚠️ TransactionsScreen: Reload method not found, using setState fallback');
              if (transactionsState.mounted) {
                transactionsState.setState(() {});
              }
            }
          } else {
            debugPrint('❌ TransactionsScreen: State not found or invalid');
          }
          break;

        case 2: // LoanListScreen - Always reload to show latest data
          final loanState = _loanKey.currentState;
          if (loanState != null && loanState is State) {
            debugPrint('💰 LoanListScreen: Triggering reload...');
            try {
              (loanState as dynamic)._loadLoans?.call();
              debugPrint('✅ LoanListScreen: Reload method called successfully');
            } catch (e) {
              debugPrint('⚠️ LoanListScreen: Reload method not found, using setState fallback');
              if (loanState.mounted) {
                loanState.setState(() {});
              }
            }
          } else {
            debugPrint('❌ LoanListScreen: State not found or invalid');
          }
          break;

      // Statistics and Profile tabs - minimal reload for better performance
        case 3: // StatisticsScreen
          final statisticsState = _statisticsKey.currentState;
          if (statisticsState != null && statisticsState is State) {
            debugPrint('📊 StatisticsScreen: Triggering reload...');
            try {
              (statisticsState as dynamic).refreshData?.call();
              debugPrint('✅ StatisticsScreen: Reload method called successfully');
            } catch (e) {
              debugPrint('⚠️ StatisticsScreen: Reload method not found, using setState fallback');
              if (statisticsState.mounted) {
                statisticsState.setState(() {});
              }
            }
          } else {
            debugPrint('❌ StatisticsScreen: State not found or invalid');
          }
          break;
        case 4: // ProfileScreen
          debugPrint('👤 ProfileScreen: No automatic reload needed');
          break;

        default:
          debugPrint('❓ Unknown tab index: $tabIndex');
          break;
      }
    });
  }

  /// Immediate reload for tabs - more aggressive approach
  void _triggerTabReloadImmediate(int tabIndex) {
    debugPrint('🚀 IMMEDIATE reload triggered for tab $tabIndex');

    switch (tabIndex) {
      case 0: // HomePage
        debugPrint('🏠 HomePage: Force reloading...');
        final homeState = _homeKey.currentState;
        if (homeState != null && homeState is State && homeState.mounted) {
          try {
            // Try multiple methods to ensure reload
            (homeState as dynamic)._refreshHomeData?.call();
            (homeState as dynamic).refreshData?.call();
            (homeState as dynamic)._loadData?.call();
            homeState.setState(() {});
            debugPrint('✅ HomePage: Multiple reload methods called');
          } catch (e) {
            debugPrint('⚠️ HomePage: Using setState fallback - $e');
            homeState.setState(() {});
          }
        } else {
          debugPrint('❌ HomePage: State not available');
        }
        break;

      case 1: // TransactionsScreen
        debugPrint('💳 TransactionsScreen: Force reloading...');
        final transactionsState = _transactionsKey.currentState;
        if (transactionsState != null && transactionsState is State && transactionsState.mounted) {
          try {
            // Try multiple methods to ensure reload
            (transactionsState as dynamic)._loadData?.call();
            (transactionsState as dynamic).refreshData?.call();
            (transactionsState as dynamic)._fetchTransactions?.call();
            transactionsState.setState(() {});
            debugPrint('✅ TransactionsScreen: Multiple reload methods called');
          } catch (e) {
            debugPrint('⚠️ TransactionsScreen: Using setState fallback - $e');
            transactionsState.setState(() {});
          }
        } else {
          debugPrint('❌ TransactionsScreen: State not available');
        }
        break;

      case 2: // LoanListScreen
        debugPrint('💰 LoanListScreen: Force reloading...');
        final loanState = _loanKey.currentState;
        if (loanState != null && loanState is State && loanState.mounted) {
          try {
            // Try multiple methods to ensure reload
            (loanState as dynamic)._loadLoans?.call();
            (loanState as dynamic).refreshData?.call();
            loanState.setState(() {});
            debugPrint('✅ LoanListScreen: Multiple reload methods called');
          } catch (e) {
            debugPrint('⚠️ LoanListScreen: Using setState fallback - $e');
            loanState.setState(() {});
          }
        } else {
          debugPrint('❌ LoanListScreen: State not available');
        }
        break;

      case 3: // StatisticsScreen
        debugPrint('📊 StatisticsScreen: Light refresh');
        break;
      case 4: // ProfileScreen
        debugPrint('👤 ProfileScreen: Light refresh');
        break;

      default:
        debugPrint('❓ Unknown tab index: $tabIndex');
        break;
    }

    // Add a small delay and try again if needed
    Future.delayed(const Duration(milliseconds: 100), () {
      _triggerTabReloadDelayed(tabIndex);
    });
  }

  /// Delayed reload as backup
  void _triggerTabReloadDelayed(int tabIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 DELAYED reload for tab $tabIndex');

      switch (tabIndex) {
        case 0: // HomePage
          final homeState = _homeKey.currentState;
          if (homeState != null && homeState is State && homeState.mounted) {
            try {
              (homeState as dynamic)._refreshHomeData?.call();
            } catch (e) {
              homeState.setState(() {});
            }
          }
          break;

        case 1: // TransactionsScreen
          final transactionsState = _transactionsKey.currentState;
          if (transactionsState != null && transactionsState is State && transactionsState.mounted) {
            try {
              (transactionsState as dynamic)._loadData?.call();
            } catch (e) {
              transactionsState.setState(() {});
            }
          }
          break;

        case 2: // LoanListScreen
          final loanState = _loanKey.currentState;
          if (loanState != null && loanState is State && loanState.mounted) {
            try {
              (loanState as dynamic)._loadLoans?.call();
            } catch (e) {
              loanState.setState(() {});
            }
          }
          break;
      }
    });
  }

  /// Method to trigger HomePage reload from external sources
  void refreshHomePage() {
    debugPrint('🔄 External refresh request for HomePage');
    final homeState = _homeKey.currentState;
    if (homeState != null && homeState is State && homeState.mounted) {
      try {
        (homeState as dynamic).refreshData?.call();
        debugPrint('✅ HomePage: External refresh completed');
      } catch (e) {
        debugPrint('⚠️ HomePage: External refresh fallback - $e');
        homeState.setState(() {});
      }
    }
  }

  /// Method to trigger TransactionsScreen reload from external sources
  void refreshTransactionsScreen() {
    debugPrint('🔄 External refresh request for TransactionsScreen');
    final transactionsState = _transactionsKey.currentState;
    if (transactionsState != null && transactionsState is State && transactionsState.mounted) {
      try {
        (transactionsState as dynamic).loadData?.call();
        debugPrint('✅ TransactionsScreen: External refresh completed');
      } catch (e) {
        debugPrint('⚠️ TransactionsScreen: External refresh fallback - $e');
        transactionsState.setState(() {});
      }
    }
  }

  /// Method to trigger LoanListScreen reload from external sources
  void refreshLoanListScreen() {
    debugPrint('🔄 External refresh request for LoanListScreen');
    final loanState = _loanKey.currentState;
    if (loanState != null && loanState is State && loanState.mounted) {
      try {
        (loanState as dynamic).loadLoans?.call();
        debugPrint('✅ LoanListScreen: External refresh completed');
      } catch (e) {
        debugPrint('⚠️ LoanListScreen: External refresh fallback - $e');
        loanState.setState(() {});
      }
    }
  }

  /// Method to trigger StatisticsScreen reload from external sources
  void refreshStatisticsScreen() {
    debugPrint('🔄 External refresh request for StatisticsScreen');
    final statisticsState = _statisticsKey.currentState;
    if (statisticsState != null && statisticsState is State && statisticsState.mounted) {
      try {
        (statisticsState as dynamic).refreshData?.call();
        debugPrint('✅ StatisticsScreen: External refresh completed');
      } catch (e) {
        debugPrint('⚠️ StatisticsScreen: External refresh fallback - $e');
        statisticsState.setState(() {});
      }
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
